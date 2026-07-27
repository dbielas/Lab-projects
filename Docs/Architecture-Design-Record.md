# ADR-001: Enterprise Hybrid Identity Infrastructure & Sync Architecture

* **Status:** Approved / Implemented
* **Date:** July 2026
* **Author:** Systems & Infrastructure Engineering
* **Scope:** Enterprise Hybrid Identity Bridge (Windows Server 2025 AD DS $\rightarrow$ Microsoft Entra ID)

---

## 1. Context and Problem Statement

The organization requires a unified identity lifecycle management model to support cloud-native platforms while maintaining on-premises Active Directory Domain Services (AD DS) as the authoritative identity source.

Legacy implementation patterns often co-locate hybrid identity synchronization agents directly on Active Directory Domain Controllers, rely on high-privilege installer shortcuts (such as Enterprise Admin credentials), and leverage outdated transport protocols (NTLM / TLS 1.0). 

We require an architecture that connects a **Windows Server 2025 AD DS forest** to a **Microsoft Entra ID tenant** while strictly adhering to Tier-0 control plane isolation, least-privilege administrative access, and Zero-Trust network transport principles.

---

## 2. Decision Drivers

* **Control Plane Isolation:** Protect Tier-0 assets (Domain Controllers) by isolating identity synchronization engines on dedicated member servers.
* **Least Privilege:** Eliminate dependencies on permanent Enterprise Admin/Domain Admin privileges for installation and routine synchronization operations.
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