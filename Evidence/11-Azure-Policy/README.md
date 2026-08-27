# Enterprise Landing Zone Guardrails via Azure Policy

## 1. Overview & Architectural Objective
In an enterprise Hub-and-Spoke topology, workload virtual machines residing in spoke VNets must not be assigned Public IP addresses. Direct public IP assignments bypass centralized security perimeters (Azure Firewall / NVA), expose compute instances directly to the public internet, and introduce asymmetric routing loops when default routes (`0.0.0.0/0`) are enforced via User Defined Routes (UDRs).

This project implements a preventative **Azure Policy Guardrail** assigned at the Resource Group scope. The custom policy evaluates incoming Azure Resource Manager (ARM) deployment requests and triggers an explicit `Deny` action against any Network Interface (NIC) containing a public IP configuration.

---

## 2. Policy Definition & Deployment

### Policy Rule Definition ([deny-nic-public-ip](./deny-nic-public-ip.json))
The policy inspects resources of type `Microsoft.Network/networkInterfaces` and asserts that the `publicIpAddress.id` property inside the IP configuration array does not exist.

```json
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Network/networkInterfaces"
      },
      {
        "not": {
          "field": "Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIpAddress.id",
          "exists": "false"
        }
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
```

### Deployment Commands (Azure CLI)

```bash
# 1. Register Custom Policy Definition
az policy definition create \
  --name "deny-nic-public-ip" \
  --display-name "Enforce Private-Only: Deny Public IPs on NICs" \
  --description "Prevents attachment of Public IP addresses to NICs in alignment with Hub-Spoke Landing Zone guardrails." \
  --rules deny-nic-public-ip.json \
  --mode All

# 2. Assign Policy to Workload Resource Group
az policy assignment create \
  --name "assign-deny-nic-public-ip" \
  --display-name "Enforce Private-Only Spoke NICs" \
  --policy "deny-nic-public-ip" \
  --resource-group "rg-lab-test"
```

---

## 3. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **1. Policy as Code** | Azure CLI / ARM | [deny-nic-public-ip](./deny-nic-public-ip.json) | JSON definition enforcing boolean condition against `Microsoft.Network/networkInterfaces/ipConfigurations[*].publicIpAddress.id`. |
| **2. Policy Assignment** | Azure Portal / CLI | [policy-assignment](./policy-assignment.jpg) | Policy assigned to target resource group `rg-lab-test` with enforcement mode enabled (`Default`). |
| **3. Preventative Enforcement (Negative Test)** | Azure CLI | [policy-violation-error](./policy-violation-error.jpg) | Deployment of `nic-policy-violation-test` terminated with error `RequestDisallowedByPolicy`. |
| **4. Compliance Telemetry** | Azure Policy Compliance Blade | [policy-compliance.jpg](./policy-compliance.jpg) | Compliance state verifies active evaluation against existing and newly requested resources. |

---

## 4. Deep-Dive Technical Analysis

### Preventative Enforcement vs. Reactive Remediation
* **Zero Trust Shift-Left:** Rather than relying on reactive detection (e.g., Defender for Cloud alerts or daily compliance scans), Azure Policy evaluates requests at the ARM control plane prior to resource provisioning.
* **Deterministic Deployment Failure:** When a non-compliant NIC provisioning request is submitted, Azure Resource Manager denies the API request during pre-flight validation, returning an HTTP `403 Forbidden` with code `RequestDisallowedByPolicy`.

```text
(RequestDisallowedByPolicy) Resource 'nic-policy-violation-test' was disallowed by policy: 'Enforce Private-Only Spoke NICs'.
Target: /subscriptions/6d04a6ec-6ce4-4637-a497-b8479df4c5b8/resourceGroups/rg-lab-test/providers/Microsoft.Network/networkInterfaces/nic-policy-violation-test
Policy Definition ID: /subscriptions/6d04a6ec-6ce4-4637-a497-b8479df4c5b8/providers/Microsoft.Authorization/policyDefinitions/deny-nic-public-ip
```

### Operational & Architectural Impact
1. **Perimeter Integrity:** Eliminates shadow ingress points by ensuring all workload subnets communicate strictly over private IP space.
2. **Asymmetric Route Prevention:** Guarantees that outbound return traffic always honors the `0.0.0.0/0` next-hop virtual appliance route rather than conflicting with direct Internet gateway egress.
3. **Governance Scalability:** The policy definition can be elevated from the resource group scope to the Subscription or Management Group level to enforce consistent landing zone baseline controls across multi-subscription environments.
