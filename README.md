# RoMA
## About RoMA
Roma is an anti-tracking scheme making use of concurrent virtual network interfaces (VIFs). 
To do this we create a pool of virtual interfaces, which is associated with the same access point.
Then all the [0;15[ seconds, we create a new one and destroy an old one.
All the interfaces have this own mac address.
This two point makes tracking more difficult for an attacker.
When the operating system has more than one default network path, it tries to equally split the traffic on each with ECMP.
For our usage, we need to limit application to only one path at the time. 
To do this we implement a small kernel patch to make the splitting depending on PID and not on source/destination server.

## Requirements
To use this project you need :
    - Network card which use ATH9K DRIVER (tested with Qualcomm Atheros QCA9377)
    - Linux distribution ( >= 5.18)
    - Install custom kernel / custom patch 
    - Packages : 
        - netctl
        - dhcpcd
        - macchanger
        - iw
        - iproute2 (ip route, ip rule, ss)

## Utilisation guide
Since all is installed and your kernel is patch. 
You only have to launch the script rotation.sh in this way : 
```
./rotation.sh [NUMBER OF VIRTUAL INTERFACES] [SSID OF THE NETWORK] [PASSWORD OF NETWORK]
```
Then the script will setup all the system and when it's ready begin the rotation.
To stop RoMA, you have to press CTRL^C. 
It will stop properly and reset the system to its initial state.

## FAQ
### Can I use the system without modifing my kernel?
You can use RoMA without patching the kernel but you lose the PID routing. 
Processus will split randomly their socket on all the virtuals interfaces, so if an attacker listen, traffic, he could infer on it and guess that the traffic is owned by the same computer wich use our system.