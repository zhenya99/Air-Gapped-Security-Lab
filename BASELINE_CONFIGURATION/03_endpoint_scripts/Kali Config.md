**1. Flush the Network Interface**

First, strip any existing or conflicting IP addresses off the network card to ensure a completely clean slate. (Assuming your interface is eth0):

* *sudo ip addr flush dev eth0*





2\. Hardcode the Static IP Profile

Use the NetworkManager command-line tool to inject your Attacker IP and Juniper Gateway into the active connection profile. (If your connection is named something other than "Wired connection 1" when you run nmcli connection show, replace it inside the quotes):

* *sudo nmcli connection modify "Wired connection 1" ipv4.method manual ipv4.addresses 192.168.66.50/24 ipv4.gateway 192.168.66.1*







**3. Bounce the Connection**

Bring the network interface down and immediately back up so it applies the new static settings:



* *sudo nmcli connection down "Wired connection 1"*
* *sudo nmcli connection up "Wired connection 1"*



**4. Verify the Configuration**

Run these three commands to ensure the interface is clean, the route is firmly set, and the traffic is successfully reaching the edge of your Victim network:



*# 1. Verify only 192.168.66.50 is assigned*

* *ip a*



*# 2. Verify the default gateway points to 192.168.66.1*

* *ip route*



*# 3. Test connectivity to the Victim network gateway*

* *ping 172.16.10.1*

