**Phase 1: The Network Interface Baseline**
To maintain a "dual-homed" setup (Wi-Fi for the internet, Ethernet for the air-gapped lab), the physical Ethernet adapter must be statically assigned to the Management network without a Default Gateway.



Open **PowerShell** as **Administrator** and run this command (replace "*Ethernet*" if your adapter is named differently):



* *New-NetIPAddress -InterfaceAlias "Ethernet" -IPAddress 172.16.99.10 -PrefixLength 24*





**Phase 2: The Persistent Lab Route**

Because the Ethernet interface lacks a default gateway, Windows has a blind spot for your Victim network. Configure  explicitly the OS how to reach VLAN 10.



* *route -p add 172.16.0.0 mask 255.255.0.0 172.16.99.1*
* *route -p add 192.168.66.0 mask 255.255.255.0 172.16.99.1*





***Phase 3: The SSH Cryptography Bypass***

To prevent modern Windows 11 from dropping connections to your enterprise networking gear due to mismatched, legacy key-exchange algorithms, you must permanently authorize them in your user profile.



Open a standard (non-admin) PowerShell window and run this entire block to automatically build your .ssh\\config file:



* *$sshDir = "$env:USERPROFILE\\.ssh"*
* *if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir }*
* 
* *$configContent = @"*
* *# Juniper SRX300 (Gateway)*
* *Host 172.16.99.1*
* &#x20;   *KexAlgorithms +diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1*
* &#x20;   *HostKeyAlgorithms +ssh-rsa*
* 
* *# Cisco Catalyst 2960-X (Switch)*
* *Host 172.16.99.2*
* &#x20;   *KexAlgorithms +diffie-hellman-group-exchange-sha1,diffie-hellman-group14-sha1*
* &#x20;   *HostKeyAlgorithms +ssh-rsa*
* *"@*
* 
* *Set-Content -Path "$sshDir\\config" -Value $configContent -Encoding Ascii*





**Phase 4: Local DNS Overrides (The hosts File)**

To avoid typing IP addresses repeatedly, map your hypervisor's IP to easily memorable domain names natively within Windows.



* *Open the Start menu, type Notepad, right-click it, and select Run as administrator.*
* *Go to File > Open, navigate to C:\\Windows\\System32\\drivers\\etc.*
* *Change the file type dropdown in the bottom right from "Text Documents (\*.txt)" to "All Files (\*.\*)", and open the hosts file.*



Add this exact line to the very bottom of the document, then save and close:



* *# --- CORE INFRASTRUCTURE (VLAN 99) ---*
* *172.16.99.20    lab.home lab proxmox*
* *172.16.99.1     firewall.home firewall srx juniper*
* *172.16.99.2     switch.home switch cisco*
* *172.16.99.30    seconion.home seconion so*
* 
* *# --- ATTACKER ENVIRONMENT ---*
* *192.168.66.50   kali.home kali attacker*
* 
* *# --- VICTIMS ENVIRONMENT (VLAN 10) ---*
* *172.16.10.15    antix.home antix victim target*





**Phase 5: OS Hardening \& Optimization**



Once the above phases are complete, the station is fully operational. Verify the entire command center is functional by running these four checks from your terminal:



*# 1. Test Gateway Reachability*

* *ping firewall*



*# 2. Test Hypervisor Reachability*

* *ping lab*



*# 3. Test Victim Gateway Routing (Ensures the supernet route reached VLAN 10)*

* *ping 172.16.10.1*



*# 4. Test Target VM Reachability*

*ping antix*



*# 5. Test Switch Remote Management (Using your updated username and DNS alias)*

* *ssh soc\_admin@switch*
* *ssh root@firewall*



*# 6. Test Attacker Routing (Expect a timeout if Kali is powered off)*

* *ping kali*

