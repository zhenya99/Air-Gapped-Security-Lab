**Final-state for Juniper SRX SRX300 Router on a Stick onfiguration in standard Junos `set` command syntax.**

**### 1. Physical and Logical Interfaces**

To achieve inter-VLAN communication, standard Junos syntax requires enabling `vlan-tagging` on the physical trunk port and defining the specific `vlan-id` on each logical sub-interface.



*# The 802.1Q Trunk Link to the Cisco Switch*

* *set interfaces ge-0/0/0 vlan-tagging*
* *set interfaces ge-0/0/0.10 vlan-id 10*
* *set interfaces ge-0/0/0.10 family inet address 172.16.10.1/24*
* *set interfaces ge-0/0/0.99 vlan-id 99*
* *set interfaces ge-0/0/0.99 family inet address 172.16.99.1/24*



\# The Static External Link to the Attacker Network

* *set interfaces ge-0/0/5 unit 0 family inet address 192.168.66.1/24*



**### 2. Security Zones \& System Services**

Once the interfaces are created, they must be strictly bound to their respective security domains, and system services (like ping or SSH) must be explicitly permitted to reach the router's local interfaces.



*# Attacker Zone*

* *set security zones security-zone ATTACKER interfaces ge-0/0/5.0*
* *set security zones security-zone ATTACKER host-inbound-traffic system-services ping*



*# Management Zone*

* *set security zones security-zone MGMT interfaces ge-0/0/0.99*
* *set security zones security-zone MGMT host-inbound-traffic system-services all*
* *set security zones security-zone MGMT host-inbound-traffic protocols all*



*# Victims Zone*

* *set security zones security-zone VICTIMS interfaces ge-0/0/0.10*
* *set security zones security-zone VICTIMS host-inbound-traffic system-services ping*



**### 3. Stateful Security Policies**

By default, the SRX drops all traffic moving between different security zones; you must define explicit policies allowing traffic from both directions if necessary. The rule below explicitly permits the one-way exploit traffic from Kali into the target subnet.



*# Permit Attacker to Victim Traffic*

* *set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match source-address any*
* *set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match destination-address any*
* *set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC match application any*
* *set security policies from-zone ATTACKER to-zone VICTIMS policy ATTACK-TRAFFIC then permit*





**### 4. Allow connection to Kali from Windows**





* cli
* configure
* load set terminal





\# 1. Permit Windows to initiate contact with Kali

* set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match source-address any
* set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match destination-address any
* set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI match application any
* set security policies from-zone MGMT to-zone ATTACKER policy WIN-TO-KALI then permit



\# 2. Explicitly Deny Kali from initiating contact with Windows (Best Practice)

* *set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match source-address any*
* *set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match destination-address any*
* *set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI match application any*
* *set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then deny*
* *set security policies from-zone ATTACKER to-zone MGMT policy BLOCK-KALI then log session-init*
* commit
* exit

