# Zero Trust Administrative Access & Conditional Access Hardening

## Executive Summary
This directory contains end-to-end evidence validating the enforcement of a custom Microsoft Entra Conditional Access policy (`CA-Require-MFA-Azure-Management`) utilizing modern **Authentication Strength** controls. The policy targets a role-assignable administrative security group (`SecOps-Audit-Admins`) holding dual-plane privileges across Microsoft Entra ID (`Global Reader`) and Azure Resource Manager (`Reader`), with an isolated emergency access (break-glass) account exclusion.

---

## 1. Test Metadata
* **Tenant:** `davidbielascomcast.onmicrosoft.com`
* **Target Security Group:** `SecOps-Audit-Admins`
* **Test Subject Account:** `admin-test02@davidbielascomcast.onmicrosoft.com`
* **Policy Name:** `CA-Require-MFA-Azure-Management`
* **Target Resource:** `Microsoft Admin Portals` (App Group / Azure Management APIs)
* **Access Control:** `Require authentication strength`
* **Deployment Mode:** `Report-only`

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **1. Role Provisioning** | Microsoft Graph / ARM | [rbac-group-assignment](./rbac-group-assignment.jpg) | Group assigned `Global Reader` (Directory) & `Reader` (Subscription Scope). |
| **2. Policy Simulation** | Entra What If Tool | [what-if-target-match](./CA-Require-MFA-Azure-Management.jpg) | Policy evaluated under `Policies that will apply` for `admin-test01`. |
| **3. Safety Net Check** | Entra What If Tool | [what-if-exclusion-proof.jpg](./what-if-exclusion-proof.jpg) | Policy evaluated under `Policies that will not apply` for Break-Glass Admin. |
| **4. Telemetry Capture** | Entra Sign-in Logs | [ca-sign-in-telemetry.jpg](./ca-sign-in-telemetry.jpg) | Result: `Report-only: User action required` (`Grant Controls: Not satisfied`). |

---

## 3. Deep-Dive Analysis: Architecture & Engineering Roadblocks

### Separation of Planes & RBAC Elevation (`Forbidden: 403` Remediation)
During initial resource-plane delegation via PowerShell, a `Microsoft.Authorization/roleAssignments/write` access failure occurred:
* **Root Cause:** Strict architectural boundary between the **Identity Plane** (Entra ID Directory Roles) and the **Resource Plane** (Azure Subscriptions). Global Administrator privileges in Entra ID do not inherently grant write access to Subscription scopes.
* **Remediation:** Executed administrative delegation via an existing Subscription `Owner` security principal to grant `Reader` scope to `SecOps-Audit-Admins`, followed by an explicit token cache flush (`Connect-AzAccount -Force` / Cloud Shell restart) to mint updated role claims.

### Telemetry Analysis: Report-Only "Not Satisfied" Grant Controls
Live sign-in testing with `admin-test01` generated a `Report-only: User action required` audit log with Grant Controls flagged as **Not satisfied**:
* **Technical Note:** In `Report-only` mode, the Conditional Access engine acts passively without enforcing step-up authentication prompts. 
* **Validation:** Because the incoming authentication token lacked the high-tier Authentication Strength claims mandated by the policy, the engine correctly identified a non-compliant sign-in without breaking user workflow—proving detection efficacy prior to production enforcement.

### Break-Glass Isolation Model
The emergency access account was explicitly excluded from the Conditional Access policy while remaining intentionally absent from the `SecOps-Audit-Admins` group:
* **Fail-Safe Mechanism:** Maintains defense-in-depth against accidental group nesting and scope drift (e.g., blanket "All Users" or "All Directory Roles" policies).
* **Business Continuity:** Prevents tenant lockout during cloud identity MFA provider outages by keeping the break-glass principal cloud-only (`.onmicrosoft.com`) and out of MFA evaluation paths.

---

## 4. Artifacts

* 📄 **PowerShell Provisioning Log:** [`rbac-group-assignment.txt`](./rbac-group-assignment.txt)
* 📄 **Entra Sign-in Event Details:** [`ca-signin-report.csv`](./ca-signin-report.csv)

### Visual Evidence

#### Conditional Access Policy Configuration
![CA_Policy_Config](./CA_Policy_Config.jpg)

#### Sign-In Telemetry (Report-Only Evaluation)
![ca-sign-in-telemetry](./ca-sign-in-telemetry.jpg)

#### What If Policy Simulation & Break-Glass Exclusion
![what-if-exclusion-proof](./what-if-exclusion-proof.jpg)
