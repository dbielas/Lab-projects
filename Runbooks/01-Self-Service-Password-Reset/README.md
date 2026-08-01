# Self-Service Password Reset (SSPR) & Password Writeback Validation

## Executive Summary
This directory contains end-to-end evidence, architectural flows, and operational runbook procedures validating Microsoft Entra ID Self-Service Password Reset (SSPR) with on-premises Active Directory Password Writeback via Entra Connect (`ENTRA-SYNC01`). It demonstrates bi-directional credential synchronization, secure RPC writeback execution, and helpdesk troubleshooting patterns.

---

## 1. Test Metadata
* **Target Account:** `amercer@davidbielascomcast.onmicrosoft.com` (`Alex Mercer`)
* **Service Principal:** `ConnectSyncProvisioning_ENTRA-SYNC01_e72762af8e46`
* **Sync Server:** `ENTRA-SYNC01`
* **Domain Controller:** `DC01`
* **Validated Service:** Hybrid Password Writeback (`Azure AD SSPR` $\rightarrow$ `On-Premises AD DS`)
* **Enforced On-Premises Policy:** Minimum length 12 chars, complexity enabled, `pwdLastSet` update flag

---

## 2. Evidence Chain of Custody

| Step | System / Portal | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **01. Authentication Registration** | Entra ID Portal | `sspr-01-user-registration.jpg` | Registered target user `amercer` with required SSPR authentication methods (Authenticator App / Mobile). |
| **02. Cloud Reset Trigger** | SSPR Portal (`aka.ms/sspr`) | `sspr-02-cloud-reset-trigger.jpg` | Initiated cloud password reset sequence; verified multi-factor challenge completion. |
| **03. Writeback Signal Capture** | `ENTRA-SYNC01` | `sspr-03-event-viewer-writeback.jpg` | Captured Event ID `31005` / `31020` in Azure AD Connect Event Logs, confirming Service Bus payload receipt. |
| **04. On-Premises Audit Log** | `DC01` | `sspr-04-dc-audit-event-4724.jpg` | Verified Security Event ID `4724` (`An attempt was made to reset an account's password`) caller: `lab\svc-entra-sync`. |
| **05. Policy & Access Verification** | `DC01` & Entra ID | `sspr-05-password-verification.txt` | Executed interactive authentication using the new password; confirmed `pwdLastSet` updated on `DC01`. |

---

## 3. Architecture & Data Flow Mechanics

### High-Level Signal Path
```text
[User @ aka.ms/sspr] ──(1. Cloud Reset)──> [Entra ID SSPR Engine]
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