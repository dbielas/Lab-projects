# Enterprise Hybrid Cloud Architecture

## Overview
This repository documents a production-grade hub-and-spoke hybrid network bridging an on-premises Windows Server Active Directory environment (DC01) to multiple Azure VNets via an encrypted IPsec Site-to-Site VPN.

## Network Architecture & Topology

On-Premises Home Lab (VirtualBox) [DC01 / 10.0.2.4][cite: 1]
       │
       ▼ [IPsec Site-to-Site Tunnel]
Azure Hub & Transit VNet (Spoke 1) [VNG + GatewaySubnet UDR]
       │
       ▼ [Gateway Transit Link]
Azure Hub VNet [Azure Firewall - 10.3.1.4]
       │
       ├───────────────────────────────┐
       ▼                               ▼
Spoke 1 VNet (10.1.0.0/16)      Spoke 2 VNet (10.2.0.0/16)[cite: 1]

## Implementation Details
1. **Centralized NVA Routing:** Forced all cross-spoke and hybrid traffic through the Azure Firewall using custom UDRs on gateway and spoke subnets.
2. **Asymmetric Path Resolution:** Added persistent static routes on the on-premises RRAS interface to map cloud address spaces back through the tunnel interface[cite: 1].
3. **Stateful Security Policy:** Configured network rule collections to permit core Active Directory replication traffic (DNS, Kerberos, LDAP, SMB).

## Validation & Evidence

### Routing Table Verification
    Active Routes:
    Network Destination        Netmask          Gateway       Interface  Metric
    10.1.0.0                   255.255.0.0      On-link       169.254.0.26  35[cite: 1]
    10.2.0.0                   255.255.0.0      On-link       169.254.0.26  35

### Port Connectivity Check
    nc -zv 10.1.0.4 389
    nc -zv 10.2.0.4 88

### Firewall Log Sample
| Timestamp | Source IP | Dest IP | Protocol | Action | Rule Name |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-08-26 | 10.2.0.4 | 10.0.2.4 | TCP | Allow | Allow-AD-Sync |