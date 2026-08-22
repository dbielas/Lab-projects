# Azure Hybrid Active Directory Infrastructure Lab

## Overview
This repository contains the architecture and validation evidence for a hybrid Active Directory environment. The infrastructure bridges an on-premises network with an Azure Virtual Network (VNet) via a Site-to-Site (S2S) IPsec VPN tunnel. This enables secure cross-premises DNS resolution, domain-joined workloads, and identity synchronization via Microsoft Entra Connect.

## 1. Architecture & Topology

### Network Diagram
```mermaid
graph TD
    subgraph "On-Premises Network"
        DC01[DC01<br>AD DS / DNS<br>10.0.2.4]
        SYNC[ENTRA-SYNC01<br>Entra Connect<br>10.0.2.5]
        CPE[(On-Prem VPN Gateway)]
    end

    subgraph "Azure Cloud (vnet-hybrid-core)"
        VNG[vng-hybrid-core<br>Virtual Network Gateway<br>PIP: pip-vng-hybrid]
        VM[vm-test<br>Linux Workload<br>10.1.1.4]
    end

    DC01 -.- CPE
    SYNC -.- CPE
    VNG -.- VM

    CPE <-->|IPsec S2S Tunnel| VNG
```

### IP Address Management (IPAM)
| Hostname | Role | IP Address |
| :--- | :--- | :--- |
| **DC01** | Primary Domain Controller & DNS | `10.0.2.4` |
| **ENTRA-SYNC01** | Microsoft Entra Connect Sync Server | `10.0.2.5` |
| **vng-hybrid-core** | Virtual Network Gateway | `pip-vng-hybrid` / `GatewaySubnet` `10.1.255.0/27` |
| **vm-test** | Domain-Joined Workload (Linux) | `10.1.1.4` |

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **01. S2S Tunnel Establishment** | Azure Portal | [vpn-gateway-status](./vpn-gateway-status.png) | Confirmed S2S tunnel connectivity and bi-directional data flow between on-premises and Azure. |
| **02. Layer 3 Routing Validation** | `DC01` | [tracert-to-azure-vm](./tracert-to-azure-vm.txt) | Validated Layer 3 routing across the IPsec tunnel from the on-premises network to the Azure VNet. |
| **03. Remote Access Verification** | Local Workstation | [ssh-session-vm-test](./ssh-session-vm-test.png) | Verified remote administrative access to `vm-test` via SSH over the private IPsec tunnel. |
| **04. Cross-Premises DNS Resolution** | `vm-test` | [dig-hybrid-lan](./dig-hybrid-lan.txt) | Confirmed Azure workload resolution of the local Active Directory domain (`hybrid.lan`) via `DC01`. |
| **05. AD Port Reachability** | `vm-test` | [nc-ad-ports-check](./nc-ad-ports-check.txt) | Proved Network Security Group (NSG) allowances for Active Directory LDAP and Kerberos traffic. |
| **06. Hybrid Domain Integration** | `DC01` (ADUC) | [aduc-vm-test-object](./aduc-vm-test-object.png) | Demonstrated successful hybrid domain join of the Linux workload into the local Active Directory. |
| **07. Entra ID Synchronization** | `ENTRA-SYNC01` | [entra-sync-export-log](./entra-sync-export-log.csv) | Verified successful identity and object synchronization to the Azure AD / Entra ID tenant. |

## 3. Tunnel Health & Layer 3 Routing
*   **Gateway Status:** *(Insert screenshot: Azure Portal showing the VPN Connection status as "Connected" with visible "Data in" and "Data out" metrics)*
*   **Trace Routing:** *(Insert text/screenshot: Output of `tracert 10.1.1.4` from `DC01` showing ICMP packets correctly routing through the on-premises gateway and across the IPsec tunnel)*
*   **SSH Validation:** *(Insert screenshot: Terminal successfully SSH'd into the Linux VM `10.1.1.4` from the local network)*

## 4. Name Resolution & Core Services
Hybrid AD relies entirely on flawless DNS. This validates that the Azure VNet can communicate with the domain controller:

*   **Cross-Premises DNS:** *(Insert text/screenshot: Output of `dig @10.0.2.4 hybrid.lan +short` from the Linux VM)*
*   **Port Validation:** *(Insert text: Output of `nc -zv 10.0.2.4 389` (LDAP) and `nc -zv 10.0.2.4 88` (Kerberos) from the Linux VM proving NSGs and firewalls allow AD traffic)*

## 5. Domain Integration
This serves as the ultimate proof of the hybrid connection working:

*   **Active Directory Computer Object:** *(Insert screenshot: Active Directory Users and Computers (ADUC) on `DC01` showing the `vm-test` computer object populated in the correct Organizational Unit)*
*   **Entra Connect Sync:** *(Insert CSV/screenshot: Synchronization Service Manager on `ENTRA-SYNC01` showing a successful "Export" operation to Azure AD)*

---
**Troubleshooting Notes:** 
*   **Bastion Bypass:** During initial configuration, the Azure Bastion Developer SKU experienced a regional DNS resolution failure (`NODATA` response from Traffic Manager). Management operations were successfully rerouted through the Site-to-Site VPN as an out-of-band management fallback.
