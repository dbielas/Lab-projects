# Identity Security, RBAC & Administrative Boundary Controls

## 1. Executive Summary & Tiering Strategy
* Implementation of the Microsoft Enterprise Access Model (Tier 0 / Tier 1 / Tier 2 isolation).
* Justification for placing `ENTRA-SYNC01` in the Tier-0 Control Plane boundary without granting it Domain Controller rights.

## 2. Least-Privilege Active Directory Service Accounts
* **Account Design:** `svc-entrasync` Service Account profile.
* **Pre-Delegated ACL Matrix:**
  * Granular rights breakdown: Read All Properties, Replicating Directory Changes / Changes All (PHS requirement), Reset Password / Write Lockout (SSPR requirement).
  * Target OU scoping: Restricting writeback ACLs strictly to `OU=Users,OU=Synced_Objects`.
* **Explicit Exclusion:** Why Enterprise Admin and Domain Admin rights are prohibited during installation and runtime.

## 3. Entra ID Role Assignment & Authentication Models
* **Cloud Role Isolation:** Use of `Hybrid Identity Administrator` for setup vs. background `Directory Synchronization Accounts` for daily processing.
* **Application-Based Authentication (ABA):** Transitioning away from legacy user credentials to MSAL certificate/token authentication for sync engine telemetry.

## 4. Active Directory Forest Hardening (Server 2025 Features)
* **gMSA Integration:** Plan for migrating service accounts to Group Managed Service Accounts (gMSAs) to eliminate static passwords.
* **Protected Users Group & Kerberos Policies:**
  * Placing privileged accounts into the Protected Users security group.
  * Restricting TGT lifetimes to 4 hours and disabling NTLM fallback.
* **Authentication Policy Silos:** Restricting where service credentials can be cached or used for interactive sign-in.

## 5. Password Security & Writeback Mechanics
* **Password Hash Synchronization (PHS):** Explanation of salted SHA-256 hash derivative generation on-premises before transmission over TLS.
* **Self-Service Password Reset (SSPR):** End-to-end security sequence for cloud-initiated password resets writing back to `DC01`.

## 6. Audit Logging, Event ID Telemetry & Monitoring
* Enabling administrative event logging via `Set-ADSyncAADCompanyFeature -AuditAdminEvents $true`.
* Key Security Event IDs to monitor on `DC01` and `ENTRA-SYNC01`:
  * **Event ID 4724:** Password reset attempt initiated by gMSA/Sync account.
  * **Event ID 4662:** Operation performed on an Active Directory object (DS-Replication checks).