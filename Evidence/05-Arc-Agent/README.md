# Hybrid Cloud Infrastructure: Active Directory, Entra Connect & Azure Arc Integration

## Overview
This repository documents the deployment, configuration, and hybrid management of a virtualized enterprise infrastructure lab. The project demonstrates an on-premises **Active Directory Domain Services (AD DS)** environment integrated with **Microsoft Entra ID** via **Entra Connect**, fully onboarded into the **Azure Arc control plane** for centralized management and telemetry logging using the **Azure Monitor Agent (AMA)**.

---

## Topology & Infrastructure Architecture

| Hostname | Role | IP Address | Operating System | Managed Services |
| :--- | :--- | :--- | :--- | :--- |
| **DC01** | Primary Domain Controller (`hybrid.lan`), DNS Server | `192.168.10.10` | Windows Server 2022 | AD DS, DNS, Azure Arc Agent, AMA |
| **ENTRA-SYNC01** | Domain Member Server, Identity Sync Engine | `192.168.10.11` | Windows Server 2022 | Entra Connect Sync, Azure Arc Agent, AMA |

---

## Section 1: Hybrid Directory Synchronization (Entra Connect)

To establish hybrid identity capabilities, `ENTRA-SYNC01` executes continuous directory synchronization between the local Active Directory domain (`hybrid.lan`) and Microsoft Entra ID.

* **Authentication Method:** Password Hash Synchronization (PHS).
* **Service Account Hardening:** Managed Service Account (gMSA) configured with minimal permissions to read directory attributes.
* **Synchronization Scope:** Designated Organizational Units (OUs) housing lab users, groups, and hybrid identities.

---

## Section 2: Azure Arc Onboarding & Control Plane Setup

Both nodes are onboarded into Azure Resource Manager (ARM) inside the `rg-hybrid-arc` resource group using a scoped Service Principal (`sp-arc-onboarding`).

### 1. Local Arc Agent Verification
Each server runs the **Azure Connected Machine Agent (`azcmagent`)**. Node health is managed locally by the Hybrid Instance Metadata Service (`himds`).

**Powershell Command:**

    & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" show

**Node Verification Output Artifact:**

    ====================================================================
     Azure Arc Connected Machine Agent Status
    ====================================================================
    Resource Name            : ENTRA-SYNC01
    Resource Group           : rg-hybrid-arc
    Subscription ID          : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Tenant ID                : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Location                 : westus2
    VM ID                    : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    Agent Status             : Connected
    Agent Version            : 1.40.02725.1205
    Services Status          :
      himds                  : Running
      gcService              : Running
      ExtensionService       : Running
    ====================================================================

### 2. Extension Architecture & Telemetry Pipeline
Log ingestion and health monitoring are handled by the **Azure Monitor Agent (AMA)** extension (`AzureMonitorWindowsAgent`), managed dynamically by `ExtensionService` and governed by a centralized Data Collection Rule (`dcr-windows-event-logs`).

**Extension Check Command:**

    & "$env:ProgramFiles\AzureConnectedMachineAgent\azcmagent.exe" extension list

**Output:**

    Name                       State       Version       Type
    AzureMonitorWindowsAgent   Succeeded   1.31.0.0      Microsoft.Azure.Monitor

---

## Section 3: Cloud Verification & Operational Telemetry (KQL Evidence)

Continuous telemetry and health signals are verified directly inside the Log Analytics Workspace (**`law-hybrid-logs`**).

### 1. Multi-Node Heartbeat Telemetry
Confirms active connections, IP addressing, and continuous health streams across both hybrid nodes, with timestamps converted to Arizona Time (MST).

**KQL Query:**

    Heartbeat
    | where Computer contains "DC01" or Computer contains "ENTRA-SYNC"
    | summarize LastHeartbeat = max(_TimeReceived) by Computer, OSType, OSName, ComputerIP, Category
    | extend LocalTime_MST = datetime_utc_to_local(LastHeartbeat, 'US/Arizona')
    | project Computer, LocalTime_MST, OSType, OSName, ComputerIP, Category
    | sort by Computer asc

**Query Execution Results:**

| Computer | LocalTime_MST | OSType | OSName | ComputerIP | Category |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `DC01` | 2026-08-06 22:15:02 | Windows | Windows Server 2022 Datacenter | 192.168.10.10 | Azure Monitor Agent |
| `ENTRA-SYNC01` | 2026-08-06 22:15:10 | Windows | Windows Server 2022 Datacenter | 192.168.10.11 | Azure Monitor Agent |

---

### 2. Security Event Audit Ingestion
Extracts real-time security events originating from on-premises Domain Controller `DC01` (Authentication, Group Policy, and Privilege Usage).

**KQL Query:**

    Event
    | where Computer contains "DC01" and EventLog == "Security"
    | extend LocalTime_MST = datetime_utc_to_local(_TimeReceived, 'US/Arizona')
    | project LocalTime_MST, Computer, EventID, Source, RenderedDescription
    | sort by LocalTime_MST desc
    | take 10

---

## Section 4: Operational Case Study — Troubleshooting Telemetry Disruption

During hypervisor state changes (VM pause/resume cycle), `ENTRA-SYNC01` experienced a temporary telemetry drop (`dial tcp: lookup gbl.his.arc.azure.com: no such host`) while maintaining an Arc status of `Connected`.

* **Root Cause:** Stale socket states and DNS cache invalidation during host resume prevented worker engine processes from completing TLS handshakes to Azure Monitor ingestion endpoints.
* **Remediation & Recovery Runbook:**
  1. Flushed stale local DNS entries (`Clear-DnsClientCache`).
  2. Confirmed Arc Managed Identity token acquisition via local IMDS (`http://localhost:40342/metadata/identity/oauth2/token`).
  3. Purged stale local AMA buffer tables at `C:\Resources\Directory\AMADataStore\Tables\*`.
  4. Restarted `ExtensionService` to re-bind worker engine sockets.
* **Outcome:** Successfully re-established lockstep telemetry ingestion across both hybrid nodes without requiring re-registration or agent re-installation.