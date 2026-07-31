# Delta Synchronization & Identity Lifecycle Validation

## Executive Summary
This directory contains end-to-end evidence validating standard Delta Synchronization functionality and object lifecycle management from on-premises Active Directory (`DC01`) to Microsoft Entra ID via Entra Connect (`ENTRA-SYNC01`). It demonstrates routine attribute propagation, account deprovisioning (soft delete), and custom service account permission remediation.

---

## 1. Test Metadata
* **Target Account:** `amercer@davidbielascomcast.onmicrosoft.com` (`Alex Mercer`)
* **Service Principal:** `ConnectSyncProvisioning_ENTRA-SYNC01_e72762af8e46`
* **Sync Server:** `ENTRA-SYNC01`
* **Domain Controller:** `DC01`
* **Updated Attributes:** `Title` ("Systems Administrator" → "Intelligence Analyst"), `Department` ("IT" → "Cybersecurity")
* **Lifecycle Events Validated:** Attribute Delta Sync, Account Disable / Cloud Soft-Delete

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **01. Source Update** | `DC01` | [dc01-attribute-update.txt](./dc01-attribute-update.txt) | Executed `Set-ADUser`; updated `Title` and `Department` attributes on `amercer`. |
| **02. Delta Engine Trigger** | `ENTRA-SYNC01` | [delta-sync-trigger.jpg](./delta-sync-trigger.jpg) | Triggered `Start-ADSyncSyncCycle -PolicyType Delta`; result: `Success`. |
| **03. Delta Export Verification** | `ENTRA-SYNC01` | [Delta-Sync-Attribute-Export.jpg](./Delta-Sync-Attribute-Export.jpg) | Captured `Connector Space Object Properties` during Delta Export. Confirmed attribute updates staged and pushed via verified `mS-DS-ConsistencyGuid` anchor. |
| **04. Cloud Reflection** | Entra ID Portal | [entra-audit-delta-update.jpg](./entra-audit-delta-update.jpg) | Status: `Success` (`Update user`) initiated by `ConnectSyncProvisioning_*`. Verified `Department` and `JobTitle` diffs. |
| **05. Account Deprovisioning** | `DC01` & Entra ID | [entra-soft-delete-audit.jpg](./entra-soft-delete-audit.jpg) | Executed `Disable-ADAccount`. Verified `accountEnabled` set to `False` (`accountEnabled: true → false`) and target account soft-deleted/disabled in Entra ID. |

---

## 3. Deep-Dive Analysis: Engine Pipeline & Attribute Scoping

### Delta Import & Staging Mechanics
When a Delta Sync cycle runs, Entra Connect queries local AD domain controllers using high-watermark USN (Update Sequence Number) tracking to isolate modified objects rather than performing a full directory read.
* **Connector Space (CS) Staging:** Changes are staged in the local AD Connector Space before evaluating synchronization rules.
* **Metaverse (MV) Transformation:** Attribute mapping rules (e.g., `In from AD - User Common`) translate local Active Directory attributes (`title`, `department`, `userAccountControl`) to their metaverse equivalents (`jobTitle`, `department`, `accountEnabled`).
* **Export Cycle:** Transmitted over TLS 1.2 via the Graph/Provisioning endpoint using the tenant's dedicated service principal (`ConnectSyncProvisioning_*`).

---

## 4. Engineering Post-Mortem: Custom Service Account Remediation (Error 8344)

### Problem Statement
During initial deployment, utilizing a pre-provisioned custom AD Connector service account (`DOMAIN\svc-entra-sync`) resulted in export failures (`sec-error-insufficient-access-rights` / `8344`) when attempting to stamp the `mS-DS-ConsistencyGuid` attribute onto target user objects during staging.

### Root Cause Analysis
By default, standard object read/write delegation commands do not automatically grant write access to extended schema attributes like `mS-DS-ConsistencyGuid`. Because Entra Connect utilizes this attribute as the immutable source anchor binding the on-premises `ObjectGUID` to the cloud identity, missing write rights block the sync engine's export phase.

### Resolution
Applied property-specific write permissions directly to the target organizational unit (`OU=Synced_Users`) targeting descendant `user` objects via `dsacls`:

```cmd
dsacls "OU=Synced_Users,DC=lab,DC=local" /I:S /G "lab\svc-entra-sync":WP;mS-DS-ConsistencyGuid;user