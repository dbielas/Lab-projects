# Microsoft Sentinel SIEM/SOAR Deployment & Hybrid Threat Detection Validation

## Executive Summary
This directory documents the deployment and validation of **Microsoft Sentinel** layered over an existing hybrid Log Analytics Workspace (`law-hybrid-logs`). It outlines the end-to-end telemetry pipeline capturing on-premises domain security events from `DC01` and `ENTRA-SYNC01` via Azure Arc and Azure Monitor Agent (AMA), the implementation of custom KQL analytics detection rules, and automated incident triage workflows.

---

## 1. Test Metadata
* **SIEM Solution:** Microsoft Sentinel
* **Log Analytics Workspace:** `law-hybrid-logs`
* **Resource Group:** `rg-hybrid-arc`
* **Monitored Hybrid Endpoints:**
  * `DC01` (10.0.2.4) — Primary Domain Controller
  * `ENTRA-SYNC01` (10.0.2.5) — Entra Connect Sync Server
* **Data Connectors Active:**
  * Windows Security Events via AMA (`dcr-windows-event-logs`)
  * Microsoft Entra ID (AuditLogs, SignInLogs)
* **Target Detection Scenarios:**
  * On-Premises Privilege Escalation & Domain Admin Addition (Event ID `4728`)
  * Brute Force Authentication Anomalies & Account Lockouts (Event ID `4625`, `4740`)
  * Identity Sync Engine Tampering / Unauthorized Service Account Behavior

---

## 2. Evidence Chain of Custody

| Step | Source System | Evidence File / Artifact | Key Findings |
|---|---|---|---|
| **01. Sentinel Workspace Onboarding** | Azure Portal / ARM | [sentinel-workspace-provisioning](./sentinel-workspace-provisioning.txt) | Initialized Microsoft Sentinel on `law-hybrid-logs`; verified trial pricing tier and data ingestion endpoints. |
| **02. Data Connector Validation** | Microsoft Sentinel | [sentinel-connector-ama-health](./sentinel-connector-ama-health.jpg) | Confirmed active data streaming from `AzureMonitorWindowsAgent` covering Windows Security Event channels. |
| **03. Custom Analytics Rule Deploy** | Microsoft Sentinel | [sentinel-kql-rule-privilege-escalation](./sentinel-kql-rule-privilege-escalation.json) | Configured scheduled KQL detection rule triggering high-severity incidents on sensitive AD group modifications. |
| **04. Simulated Attack Execution** | `DC01` | `simulated-priv-esc-execution.txt` | Generated synthetic security telemetry by adding a target user to the local `Domain Admins` group. |
| **05. Incident Generation & Triage** | Microsoft Sentinel | `sentinel-incident-triage-evidence.jpg` | Verified automated generation of Incident `INC-1001`; mapped MITRE ATT&CK tactics (Persistence, Privilege Escalation) and entity extraction. |

---

## 3. Deep-Dive Analysis: Sentinel Detection & Analytics Engineering

### Ingestion Flow & Table Mapping
* On-premises audit policies forward Windows Event Logs to the local SQLite staging cache via `MonAgentCore.exe`.
* Telemetry streams outbound over HTTPS (TCP 443) into the `SecurityEvent` / `Event` tables in `law-hybrid-logs`.
* Sentinel’s analytics engine continuously evaluates scheduled queries against incoming log streams.

### KQL Analytics Detection Rule: Sensitive AD Group Addition
```kusto
SecurityEvent
| where EventID in (4728, 4732, 4756) // A member was added to a security-enabled group
| where TargetUserName in ("Domain Admins", "Enterprise Admins", "Schema Admins", "Account Operators")
| extend LocalTime_MST = datetime_utc_to_local(TimeGenerated, 'US/Arizona')
| project LocalTime_MST, Computer, SubjectUserName, SubjectDomainName, TargetUserName, MemberName, EventID
| sort by LocalTime_MST desc
```

### Entity Mapping Architecture
To enable automated triage and graph investigation, Sentinel maps query results directly to ARM entity identifiers:
* **Account Entity:** `SubjectUserName` (Actor), `MemberName` (Target Object)
* **Host Entity:** `Computer` (NetBIOS / FQDN)
* **IP Entity:** `IpAddress` (Originating Client IP)

---

## 4. Operational Considerations & Alert Tuning

### Alert Suppression & False-Positive Handling
* **Authorized Administrative Windows:** Built-in scheduled tasks or deployment accounts (e.g., `sp-arc-onboarding` or Entra Connect setup scripts) can trigger threshold alerts. Whitelisting specific service principals prevents incident fatigue.
* **Query Frequency vs. Lookup Period:** Detection runs on a 5-minute schedule evaluating the previous 5 minutes of data (`Query Frequency: 5m`, `Query Period: 5m`) with zero threshold to ensure near-real-time alerting on critical security events.
