# Network Architecture, Egress Matrix & Protocol Hardening

## 1. Overview & Network Topology
* Brief description of the hybrid transport plane.
* Visual/Textual Subnet & IP Map:
  * `DC01` (10.0.2.2) - AD DS / DNS / PKI
  * `ENTRA-SYNC01` (10.0.2.3) - Dedicated Sync Host
  * `MGMT01` (10.0.2.4) - Windows 11 Admin PAW
* Zero-Trust Boundary Statement: No inbound ports exposed to public transport. All cloud telemetry uses outbound-initiated HTTPS/TLS connections.

## 2. Firewall Egress & Traffic Matrix
* **Internal Segmentation Rules:**
  * Protocols, ports, and source/destination mappings between `MGMT01`, `ENTRA-SYNC01`, and `DC01` (RPC, LDAP/LDAPS, Kerberos, WinRM).
* **Outbound Egress Rules (Host & Edge Firewall):**
  * Table detailing required FQDN endpoints (`*.login.microsoftonline.com`, `*.msappproxy.net`, `*.msftidentity.com`), Ports (TCP/UDP 443), Protocol, and Justification.
  * Explicit Deny-All policy default for non-Microsoft endpoints.

## 3. Host Protocol & Cipher Suite Hardening
* **Schannel Registry Hardening Configuration:**
  * Explicit enforcement of TLS 1.2 and TLS 1.3.
  * Deprecation/Disabling of SSL 2.0, SSL 3.0, TLS 1.0, and TLS 1.1.
* **Cipher Suite Order & Weak Cipher Lockout:**
  * Removal of RC4, 3DES, and NULL ciphers.
  * Enforcing ECDHE key exchange and AES-GCM encryption suites.
* **.NET Framework Strong Cryptography Enforcement:**
  * Registry entries for `SchUseStrongCrypto` and `SystemDefaultTlsVersions` (v4.0.30319) required for MSAL engine operations.

## 4. Local Host Firewall Scripting
* PowerShell code block exporting/enforcing the Windows Defender Firewall baseline on `ENTRA-SYNC01`.

## 5. Verification & Transport Testing Commands
* PowerShell test scripts (`Test-NetConnection`, `Test-ClientAuth`) to validate outbound socket connectivity to Entra ID endpoints over port 443.
