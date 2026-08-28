# Module 12: Hybrid Business Continuity & Disaster Recovery (BCDR) via Azure Backup

## 1. Overview & Architectural Objective
To ensure workload resilience and operational recoverability across the hybrid landing zone, this module establishes a cloud-native Business Continuity and Disaster Recovery (BCDR) tier using an Azure Recovery Services Vault (RSV).

The deployment validates:
* Policy-driven snapshot orchestration on isolated spoke compute workloads.
* Zero-impact, item-level granular file recovery without requiring full VM redeployment.
* Storage-tier cost optimization utilizing Locally Redundant Storage (LRS).

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **1. Vault & Policy Provisioning** | Azure CLI | [rsv-properties.json](./rsv-properties.json) | Recovery Services Vault `rsv-hybrid-bcdr` deployed with `LocallyRedundant` storage baseline. |
| **2. Snapshot Execution** | RSV Backup Jobs | [backup-job-success.jpg](./backup-job-success.jpg) | On-demand application-consistent snapshot completed for `vm-test`. |
| **3. Item-Level File Recovery** | `vm-test` OS | [file-recovery-mount.jpg](./file-recovery-mount.jpg) | Successful mount of point-in-time recovery volume verifying data integrity and granular file extraction. |

---

## 3. Deep-Dive Technical Analysis

### Snapshot Architecture vs. Granular Recovery
* **VSS / App-Consistent Integration:** For Windows workloads, Azure Backup coordinates with the Volume Shadow Copy Service (VSS); for Linux, it quiesces the file system to take an application-consistent snapshot.
* **iSCSI Point-in-Time Mount:** File-level recovery generates a secure, authenticated script that mounts snapshot block devices over iSCSI directly into the target operating system, allowing SecOps and SysAdmins to recover individual corrupted or deleted files in minutes without compute downtime.