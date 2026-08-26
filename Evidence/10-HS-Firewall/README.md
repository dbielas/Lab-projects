# Enterprise Hybrid Cloud Architecture

## Overview
This repository documents a production-grade hub-and-spoke hybrid network bridging an on-premises Windows Server Active Directory environment (DC01) to multiple Azure VNets via an encrypted IPsec Site-to-Site VPN tunnel routed through a centralized Azure Firewall NVA.

---

## Topology

```text
+-------------------------------------------------------------+
| On-Premises Hypervisor (VirtualBox)                         |
|   - DC01 / DNS (10.0.2.4)                                   |
|   - RRAS S2S Interface: Azure-S2S-VPN (169.254.0.26)       |
+------------------------------+------------------------------+
                               |
                   [ IPsec Site-to-Site Tunnel ]
                               |
+------------------------------v------------------------------+
| Azure Spoke 1 / Transit VNet (vm-testVNET - 10.1.0.0/16)    |
|   - Virtual Network Gateway (GatewaySubnet)                 |
|   - Workload Subnet (10.1.0.0/24)                           |
|   - GatewaySubnet UDR (0.0.0.0/0 & Spokes -> Firewall)      |
+------------------------------+------------------------------+
                               |
                    [ Peering with Gateway Transit ]
                               |
+------------------------------v------------------------------+
| Azure Hub VNet (10.3.0.0/16)                                |
|   - Azure Firewall (10.3.1.4)                               |
|   - Stateful Inspection & AD Network Rules                  |
+------------------------------+------------------------------+
                               |
                    [ Peering with Use Remote Gateway ]
                               |
+------------------------------v------------------------------+
| Azure Spoke 2 VNet (10.2.0.0/16)                            |
|   - Workload Subnet (10.2.0.0/24)                           |
|   - Spoke UDR (0.0.0.0/0 & 10.0.2.0/24 -> Firewall)        |
+-------------------------------------------------------------+
```

---

## Architecture & Implementation

* **Transit Spoke Design:** `vm-testVNET` (Spoke 1, `10.1.0.0/16`) hosts the Virtual Network Gateway (VNG) while serving dual roles as both an active workload spoke and the hybrid transit network.
* **Centralized NVA Insertion:** All traffic traversing between `vm-testVNET`, `Spoke 2`, and the on-premises environment is forced through the central Azure Firewall (`10.3.1.4`) via custom User Defined Routes (UDRs).
* **Hybrid Static Routing:** Persistent static routes are configured on the on-premises RRAS gateway interface to route Azure prefixes (`10.1.0.0/16` and `10.2.0.0/16`) across the IPsec tunnel[cite: 1].
* **Stateful Identity Policy:** Azure Firewall network rules permit core Active Directory replication and query traffic (DNS, Kerberos, RPC Endpoint Mapper, LDAP, SMB, LDAPS).

---

## Validation & Proof of Connectivity

### 1. On-Premises Host Routing Table (`route print`)
```text
Active Routes:
Network Destination        Netmask          Gateway       Interface  Metric
         10.1.0.0      255.255.0.0         On-link      169.254.0.26     35
         10.2.0.0      255.255.0.0         On-link      169.254.0.26     35
```
[cite: 1]

### 2. End-to-End Port Verification (`nc`)
```bash
# Verify Active Directory LDAP reachability
nc -zv 10.0.2.4 389

# Verify Kerberos authentication reachability
nc -zv 10.0.2.4 88

# Verify DNS resolution reachability
nc -zv 10.0.2.4 53
```

### 3. Azure Firewall Log Analytics Validation (`AZFWNetworkRule`)
| Source IP | Destination IP | Protocol | Destination Port | Action | Rule |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 10.2.0.4 | 10.0.2.4 | TCP | 389 | Allow | RC-Active-Directory-Sync |
| 10.2.0.4 | 10.0.2.4 | TCP | 88 | Allow | RC-Active-Directory-Sync |
| 10.2.0.4 | 10.0.2.4 | UDP | 53 | Allow | RC-Active-Directory-Sync |
