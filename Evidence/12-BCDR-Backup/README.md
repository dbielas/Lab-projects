# Hybrid Business Continuity & Disaster Recovery (BCDR) via Azure Backup

## 1. Overview & Architectural Objective
To ensure workload resilience and operational recoverability across the hybrid landing zone, this module establishes a cloud-native Business Continuity and Disaster Recovery (BCDR) tier using an Azure Recovery Services Vault (RSV).

The deployment validates:
* Policy-driven snapshot orchestration on isolated spoke compute workloads.
* Zero-impact, item-level granular file recovery without requiring full VM redeployment or compute downtime.
* Deterministic cryptographic verification (SHA-256) of restored payload integrity.
* Storage-tier cost optimization utilizing Locally Redundant Storage (LRS).

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **1. Vault Provisioning** | Azure CLI / ARM | [rsv-properties](./rsv-properties.json) | Recovery Services Vault `rsv-hybrid-bcdr` deployed in `rg-lab-test` with `LocallyRedundant` storage baseline. |
| **2. Snapshot Execution** | RSV Backup Item (`vm-test`) | [backup-job-success](./backup-job-success.jpg) | Backup Pre-Check passed with status `Success`; created 1 `File-system Consistent` recovery point (`Snapshot and Vault-Standard`) under `DefaultPolicy`. |
| **3. Item-Level Recovery & Cryptographic Verification** | `vm-test` (`10.2.0.4`) / iSCSI Snapshot | [sha256sum](./sha256sum.jpg) | Mounted point-in-time snapshot partition (`/home/azureuser/vm-test-20260828033247/Volume1/`); SHA-256 checksum comparison confirms 100% data integrity against pre-backup baseline (`8d85dcc7b8b9d837d3315f887883c667c801e6c672dd61ed191ecc7f61c3067d`). |

---

## 3. Deep-Dive Technical Analysis

### Snapshot Architecture vs. Granular Item-Level Recovery
* **Filesystem Quiescence & Snapshot Consistency:** For Linux workloads, the Azure VM Backup extension quiesces the filesystem before capturing the managed disk snapshot, ensuring application consistency without requiring a system restart.
* **iSCSI Point-in-Time Mount Mechanism:** Azure File Recovery utilizes an authenticated, time-bound script to expose the backup snapshot volume over an encrypted iSCSI tunnel. The volume mounts directly into the target OS (`/home/azureuser/vm-test-20260828033247/Volume1/`), enabling granular file extraction and inspection without re-provisioning compute resources.

### Cryptographic Integrity Verification
Prior to backup execution, a baseline payload `/opt/bcdr-payload/critical-data.txt` was generated alongside an immutable SHA-256 hash file (`checksum.sha256`). Following recovery point creation and volume mounting:

```text
# Hash calculated on mounted recovery point
8d85dcc7b8b9d837d3315f887883c667c801e6c672dd61ed191ecc7f61c3067d  critical-data.txt

# Baseline checksum recorded prior to backup
8d85dcc7b8b9d837d3315f887883c667c801e6c672dd61ed191ecc7f61c3067d  /opt/bcdr-payload/critical-data.txt
```

The matching hash string verifies bit-for-bit data integrity between the live production state and the mounted cloud snapshot point.
