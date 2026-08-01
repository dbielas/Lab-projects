# Self-Service Password Reset (SSPR) & Password Writeback Operations Runbook

## 1. Executive Overview & Scope
* **Purpose:** Provides operational guidance for Tier 1–3 Helpdesk and Identity Engineers to manage, troubleshoot, and audit hybrid credential resets between Microsoft Entra ID and on-premises Active Directory Domain Services (`DC01`).
* **Target Audience:** Service Desk Analysts, Systems Administrators, Security Operations Center (SOC).
* **Prerequisites & Licensing:** Microsoft Entra ID P1/P2 (or M365 E3/E5), Entra Connect with Password Writeback enabled on `ENTRA-SYNC01`.

---

## 2. Architecture & System Dependencies

### High-Level Signal Flow
```text
[User @ aka.ms/sspr] ──(1. Reset Request)──> [Entra ID SSPR Engine]
                                                     │
                                          (2. Encrypted TLS Signal)
                                                     │
                                                     ▼
                                         [Azure Service Bus Endpoint]
                                                     │
                                          (3. Long-Poll Query)
                                                     │
                                                     ▼
                                         [ENTRA-SYNC01 (ADSync)]
                                                     │
                                          (4. RPC / SetPassword Call)
                                                     │
                                                     ▼
                                         [DC01 (Active Directory)]
```

### Critical Endpoints & Network Ports
* **Outbound Cloud Connectivity:** `*.servicebus.windows.net` via TCP `443`, `5671`, and `5672` from `ENTRA-SYNC01`.
* **Internal RPC Traffic:** TCP `135` (RPC Endpoint Mapper), TCP `445` (SMB), and dynamic RPC ports (`49152-65535`) between `ENTRA-SYNC01` and `DC01`.

---

## 3. Account Delegation & On-Premises ACLs

The Entra Connect custom service account (`hybrid.lan\svc-entrasync`) requires explicit delegated rights on all synced OUs containing user accounts.

### Required Active Directory Rights
* **Reset Password**
* **Write Property:** `Unexpire-Password` / `pwdLastSet`
* **Write Property:** `lockoutTime` (enables users to unlock accounts via SSPR without changing passwords)

### ACL Verification & Remediation Command
Run this command on `DC01` if permission errors occur during writeback:
```cmd
dsacls "OU=Users,OU=Synced_Objects,DC=hybrid,DC=lan" /I:S /G "hybrid.lan\svc-entrasync:RPWP;pwdLastSet;user"
```

---

## 4. Operational Health Checks & Verification

### On the Entra Connect Sync Server (`ENTRA-SYNC01`)
* **Event Viewer Navigation:** `Applications and Services Logs` $\rightarrow$ `Azure AD Connect`
  * **Event ID 31005:** Connection successfully established with Azure Service Bus.
  * **Event ID 31020 / 33006:** Password writeback failed (review event XML payload for exact error code).
* **Service Dependency:** Ensure the `Microsoft Azure AD Sync` (`ADSync`) service is running.

### PowerShell Configuration Check
```powershell
Import-Module "C:\Program Files\Microsoft Azure Active Directory Connect\Module\ADSyncConfig\ADSyncConfig.psd1"

# Verify Password Writeback state across all AD Connectors
Get-ADSyncPasswordWritebackConfiguration
```

---

## 5. Troubleshooting Decision Matrix

| Symptom / Error | Root Cause | Remediation Procedure |
| :--- | :--- | :--- |
| **User Prompt:** *"We're sorry, but we cannot reset your password at this time."* | User is missing required SSPR authentication methods (e.g., Authenticator app, phone). | Direct user to `https://aka.ms/ssprsetup` to re-register authentication methods. |
| **Event ID 31020 (`INSUFF_ACCESS_RIGHTS`)** | Service account missing `Reset Password` or `pwdLastSet` rights on target OU or user. | Verify ACL inheritance on target user object; check if `AdminSDHolder` broke inheritance for protected accounts. |
| **Password Complexity Rejection** | Proposed password violates local AD Password Policy (Fine-Grained Password Policy or Default Domain Policy). | Direct user to meet local complexity rules. Review `DC01` Security Log Event ID `4723`/`4724` for explicit rejection reasons. |
| **Writeback Timeout (31008)** | Outbound network connection blocked between `ENTRA-SYNC01` and Azure Service Bus. | Test network paths to `*.servicebus.windows.net` over ports `443` and `5671`. |

---

## 6. Audit & Compliance Reference

### Cloud Audit Trail (Entra Admin Center)
* **Service:** `Self-service Password Management`
* **Activities:** `Reset user password`, `Change user password`
* **Initiated By:** `Self-service Password Reset`

### On-Premises Security Log (`DC01`)
* **Log:** `Security`
* **Event ID 4724:** An attempt was made to reset an account's password (shows `TargetUserName` as target user and `Subject` as service account `hybrid.lan\svc-entrasync`).
* **Event ID 4723:** An attempt was made to change an account's password.
