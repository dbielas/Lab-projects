# Delta Synchronization Operations & Troubleshooting Runbook

## 1. Executive Overview & Scope
* **Purpose:** Provides Tier 1–3 Helpdesk analysts, Systems Administrators, and Identity/Security Engineers with operational guidance, sequence flows, and troubleshooting steps for standard Delta Synchronization cycles between on-premises Active Directory (`DC01`) and Microsoft Entra ID via Entra Connect (`ENTRA-SYNC01`).
* **Target Audience:** Service Desk Analysts, Systems Administrators, Security Operations Center (SOC).
* **Prerequisites & Licensing:** Microsoft Entra ID Free/P1/P2, Entra Connect deployed with standard sync scheduler enabled on `ENTRA-SYNC01`.

---

## 2. Architecture & System Dependencies

### High-Level Signal Flow
```text
[DC01 (Active Directory)] ──(1. Directory Delta via USN)──> [AD Connector Space (CS)]
                                                                    │
                                                        (2. Metaverse Rules Transform)
                                                                    │
                                                                    ▼
                                                         [Metaverse Object (MV)]
                                                                    │
                                                        (3. Outbound Graph Staging)
                                                                    │
                                                                    ▼
                                                        [Entra ID Connector Space]
                                                                    │
                                                        (4. TLS Export / Graph API)
                                                                    │
                                                                    ▼
                                                       [Microsoft Entra ID Tenant]
```

### Critical Endpoints & Network Ports
* **On-Premises LDAP & RPC:** TCP `389` (LDAP), TCP `636` (LDAP/S), TCP `135` (RPC Endpoint Mapper), and dynamic RPC range (`49152-65535`) between `ENTRA-SYNC01` and `DC01`.
* **Outbound Cloud Endpoints:** TCP `443` HTTPS outbound to `https://adminwebservice.microsoftonline.com`, `https://login.microsoftonline.com`, and Graph endpoints (`https://graph.windows.net`).

---

## 3. Account Delegation & On-Premises ACLs

The custom Entra Connect service account (`hybrid.lan\svc-entrasync`) requires read rights across target Organizational Units to evaluate Update Sequence Numbers (USNs) and inspect modified user attributes.

### Required Active Directory Rights
* **Read all properties** on descendant `user`, `group`, and `contact` objects within synchronized OUs.
* **Write Property:** `mS-DS-ConsistencyGuid` (required for immutable source anchor binding during sync staging).

### ACL Verification & Remediation Command
Run this command on `DC01` if permission errors (e.g., Error `8344` / `insufficient-access-rights`) block staging or source anchor writes:
```cmd
dsacls "OU=Users,OU=Synced_Objects,DC=hybrid,DC=lan" /I:S /G "hybrid.lan\svc-entrasync:WP;mS-DS-ConsistencyGuid;user"
```

---

## 4. Operational Health Checks & Verification

### On the Entra Connect Sync Server (`ENTRA-SYNC01`)
* **Synchronization Service Manager (`miisclient.exe`):**
  * Select **Operations** tab.
  * Look for the default 30-minute execution profiles: `Delta Import`, `Delta Sync`, and `Export`.
  * Confirm status shows `success` without `stopped-server-error` or `export-errors`.

### PowerShell Configuration & Execution Diagnostics
Run these commands in an elevated PowerShell session on `ENTRA-SYNC01`:

```powershell
# 1. Check current Sync Scheduler status, interval, and policy execution
Get-ADSyncScheduler

# 2. Trigger an immediate manual Delta Sync cycle across all connectors
Start-ADSyncSyncCycle -PolicyType Delta

# 3. Inspect recent sync connector run statuses
Get-ADSyncConnectorRunStatus
```

---

## 5. Troubleshooting Decision Matrix

| Symptom / Error | Root Cause | Remediation Procedure |
| :--- | :--- | :--- |
| **Error `8344` (`insufficient-access-rights`)** | Service account lacks `WriteProperty` rights for `mS-DS-ConsistencyGuid` on modified object. | Execute the `dsacls` remediation command in Section 3 on the target OU to grant source anchor write permissions. |
| **`SyncCycleInProgress`** | A Delta or Full sync cycle is already executing on the engine. | Run `Get-ADSyncScheduler` to check `SyncCycleInProgress`. Wait for completion or run `Stop-ADSyncSyncCycle`. |
| **Attribute Delta Not Reflecting** | Attribute modified on-premises is excluded from outbound sync rules or filtering scope. | Open `Synchronization Rules Editor`, inspect `In from AD - User Common`, and verify attribute flow mapping to Metaverse. |
| **`stopped-connectivity`** | Network timeout or LDAP/RPC connectivity loss between `ENTRA-SYNC01` and `DC01`. | Check port `389`/`636` connectivity to domain controllers and verify `ADSync` service status on `ENTRA-SYNC01`. |

---

## 6. Audit & Compliance Reference

### Cloud Audit Trail (Entra Admin Center)
* **Service:** `Core Directory`
* **Activity:** `Update user`
* **Initiated By:** `ConnectSyncProvisioning_*` (Service Principal)
* **Property Diff:** Review modified properties tab to verify specific target attribute delta changes (e.g., `Department`, `JobTitle`).

### On-Premises Sync Engine Logs (`ENTRA-SYNC01`)
* **Log Path:** `miisclient.exe` $\rightarrow$ **Operations** $\rightarrow$ Double-click **Delta Export** step $\rightarrow$ Select object row $\rightarrow$ **Connector Space Object Properties**.
* **Staging Audit:** Confirms attribute `Old Value` vs `New Value` diffs prior to cloud export.