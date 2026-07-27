# ADR-001: Enterprise Hybrid Identity Infrastructure & Sync Architecture

* **Status:** Approved / Implemented
* **Date:** July 2026
* **Author:** Systems & Infrastructure Engineering
* **Scope:** Enterprise Hybrid Identity Bridge (Windows Server 2025 AD DS -> Microsoft Entra ID)

---

## 1. Context and Problem Statement

The organization requires a unified identity lifecycle management model to support cloud-native platforms while maintaining on-premises Active Directory Domain Services (AD DS) as the authoritative identity source.

Legacy implementation patterns often co-locate hybrid identity synchronization agents directly on Active Directory Domain Controllers, rely on high-privilege installer shortcuts (such as Enterprise Admin credentials), and leverage outdated transport protocols (NTLM / TLS 1.0). 

We require an architecture that connects a Windows Server 2025 AD DS forest to a Microsoft Entra ID tenant while strictly adhering to Tier-0 control plane isolation, least-privilege administrative access, and Zero-Trust network transport principles.

---

## 2. Decision Drivers

* **Control Plane Isolation:** Protect Tier-0 assets (Domain Controllers) by isolating identity synchronization engines on dedicated member servers.
* **Least Privilege:** Eliminate dependencies on permanent Enterprise Admin or Domain Admin privileges for installation and routine synchronization operations.
* **Authentication Resilience:** Provide high-availability cloud authentication that remains functional even during on-premises WAN outages.
* **Transport Layer Security:** Enforce modern cryptography (TLS 1.2/1.3) and strict outbound network egress filtering.
* **Maintainability & Portability:** Automate directory structure creation and ACL delegation using reusable PowerShell modules.

---

## 3. Considered Options

1. **Option A:** Direct Entra Connect Sync installation on Primary Domain Controller (`DC01`) using Express Settings.
2. **Option B:** Entra Cloud Sync Agents deployed across Domain Controllers.
3. **Option C (Chosen):** Dedicated Member Server (`ENTRA-SYNC01`) running Entra Connect Sync v2.x with Custom Settings, pre-delegated service accounts, and Application-Based Authentication (ABA).

---

## 4. Decision Outcome

**Chosen Option:** **Option C**

We will deploy a dedicated, isolated Windows Server 2025 member server (`ENTRA-SYNC01`) hosting **Entra Connect Sync v2.x**. The sync engine will communicate with Active Directory via a dedicated service account with granularly delegated Access Control Lists (ACLs) and communicate outbound to Entra ID using TLS 1.2+ via UDP/TCP 443.

### Key Architectural Choices:

* **Password Hash Sync (PHS) as Primary Authentication:**
  Provides maximum availability. If on-premises internet connectivity fails, users can still authenticate to cloud resources using synced password hashes (salted SHA-256).

* **Dedicated Sync Host (`ENTRA-SYNC01`):**
  Preserves Tier-0 boundary integrity. Co-locating third-party agents and web/database services on DCs expands the attack surface of the core domain.

* **Pre-Delegated Service Account (`svc-entrasync`):**
  Using the `AdSyncConfig` PowerShell module allows us to grant exact permissions (`DS-Replication-Get-Changes` for PHS, target OU write rights for SSPR) without ever exposing Enterprise Admin credentials to the setup wizard.

* **Targeted OU Filtering (`OU=Synced_Objects`):**
  Restricts sync scope to specific administrative boundaries, preventing staging clutter, sync loops, or unintended cloud exposure of default AD system containers.

---

## 5. Architectural Trade-offs & Analysis

| Strategy Dimension | Chosen Architecture (Option C) | Rejected Alternative (Option A - Express on DC) |
| :--- | :--- | :--- |
| **Security Boundary** | High (Isolated on Tier-0 member server) | Low (Agent expands DC attack surface) |
| **Credential Safety** | High (Targeted ACLs, no EA rights) | Medium (EA rights used during setup) |
| **Compute Overhead** | Dedicated host resource allocation | Resource contention with local AD DS/DNS |
| **Operational Effort** | Medium (Requires initial manual ACL setup) | Low (Click-next installer) |

---

## 6. Security and Compliance Controls

* **Transport Layer Security:** Enforced TLS 1.2/1.3 via system registry policy on `ENTRA-SYNC01`. Explicitly disabled SSL 3.0, TLS 1.0, TLS 1.1, and weak ciphers.
* **Network Egress Isolation:** Host and firewall rules restrict outbound egress from `ENTRA-SYNC01` strictly to Microsoft FQDNs (`*.login.microsoftonline.com`, `*.msappproxy.net`) over TCP 443. Zero inbound ports are open.
* **Auditing:** Enabled administrative event logging (`Set-ADSyncAADCompanyFeature -AuditAdminEvents $true`) to capture all sync rule modifications and schema changes.

---

## 7. Implementation Validation Criteria

The architecture is deemed validated when:
1. `miisclient.exe` demonstrates successful import/export pipelines between local Connector Space, Metaverse, and Entra ID Connector Space.
2. User attributes (`Department`, `Title`, `Mail`, `UPN`) reflect accurately in the Entra ID Portal.
3. Triggering a cloud SSPR password reset generates local **Security Event ID 4724** on `DC01` within 10 seconds.
