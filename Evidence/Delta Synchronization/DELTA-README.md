# Delta Synchronization & Attribute Lifecycle Validation

## Executive Summary
This directory contains end-to-end evidence validating standard Delta Synchronization functionality from on-premises Active Directory (`DC01`) to Microsoft Entra ID via Entra Connect (`ENTRA-SYNC01`). It demonstrates routine attribute lifecycle management and object attribute propagation.

---

## 1. Test Metadata
* **Target Account:** `testuser2@davidbielascomcast.onmicrosoft.com`
* **Service Principal:** `ConnectSyncProvisioning_ENTRA-SYNC01_e72762af8e46`
* **Sync Server:** `ENTRA-SYNC01`
* **Domain Controller:** `DC01`
* **Modified Attributes:** `Title` ("Senior Systems Administrator"), `Department` ("Information Technology")

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **1. Source Update** | `DC01` | `dc01-attribute-update.png` | Executed `Set-ADUser`; updated `Title` and `Department` attributes |
| **2. Delta Engine Trigger** | `ENTRA-SYNC01` | `delta-sync-trigger.png` | Triggered `Start-ADSyncSyncCycle -PolicyType Delta`; result: `Success` |
| **3. Engine Execution** | `ENTRA-SYNC01` | `miisclient-delta-step.png` | `miisclient.exe` showing `Delta Import` and `Delta Sync` completed with `Updates: 1` |
| **4. Cloud Reflection** | Entra ID Portal | `entra-audit-delta-update.png` | Status: `Success` (`Update user`) initiated by `ConnectSyncProvisioning_ENTRA-SYNC01_*` |

---

## 3. Deep-Dive Analysis: Engine Pipeline & Attribute Scoping

### Delta Import & Staging Mechanics
When a Delta Sync cycle runs, Entra Connect queries local AD domain controllers using high-watermark USN (Update Sequence Number) tracking to isolate modified objects rather than performing a full directory read.
* **Connector Space (CS) Staging:** Changes are staged in the local AD Connector Space before evaluating synchronization rules.
* **Metaverse (MV) Transformation:** Attribute mapping rules (e.g., `In from AD - User Common`) translate local Active Directory attributes (`title`, `department`) to their metaverse equivalents (`jobTitle`, `department`).
* **Export Cycle:** Transmitted over TLS 1.2 via the Graph/Provisioning endpoint using the tenant's dedicated service principal (`ConnectSyncProvisioning_*`).

### Scope & Attribute Filtering Checks
During delta evaluations, attributes are validated against the active schema filters configured during Entra Connect setup.
* **Direct Schema Mapping:** Standard organizational fields (`Title` $\rightarrow$ `jobTitle`, `Department` $\rightarrow$ `department`) sync out-of-the-box without custom sync rule overrides.
* **Audit Trail Differential:** Unlike credential operations (`Update PasswordProfile`), general metadata updates write to Entra Audit logs with **Activity:** `Update user` under **Service:** `Core Directory`, populating modified property lists with both old and new string values.