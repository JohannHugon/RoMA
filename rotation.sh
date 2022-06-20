#!/bin/sh

###################################################################
#Script Name    : rotation.sh                                                                                             
#Description    : Initialise the system and then start virtual interfaces rotation                                                                     
#Args           : $1 : Number of interface
#                 $2 : SSID of your network                                      
#                 $3 : Password of your network                                      
#Author         : Johann Hugon                                                
#Email          : johann.hugon@pm.me                                           
###################################################################


connectVI() {
    INDEX=$1
    TABLE=T"$INDEX"
    VI="$VI_PREFIX$INDEX"
    netctl start "$VI"-"$SSID"
    netctl wait-online "$VI"-"$SSID"
    # Create table $TABLE if not exist
    if ! grep -q "$TABLE"  /etc/iproute2/rt_tables
    then
       	echo "$INDEX       $TABLE" >> /etc/iproute2/rt_tables
    fi

    IP=$(ip a show dev "$VI" | grep 'inet ' | xargs |cut -d' ' -f2 | cut -d'/' -f1)
    NETWORK=$(ip route | grep -v default | grep "$VI" | awk '{print $1;}') 
    GATEWAY=$(ip route | grep default | grep "$VI_PREFIX"1 | awk '{print $3}') ## Dirty

    ip route add "$NETWORK" dev "$VI" src "$IP" table "$TABLE"
    ip route add default via "$GATEWAY" dev "$VI" table "$TABLE"
    ip rule add from "$IP" table "$TABLE"
}

stop() {
    echo "##### Stoping rotation #####"
    for I in $LIST_VI
    do
        VI="$VI_PREFIX$I"
        DEL_IP=$(ip a show dev "$VI" | grep 'inet ' | xargs |cut -d' ' -f2 | cut -d'/' -f1)
        ss -K src = "$DEL_IP" > /dev/null
        dhcpcd -q -k -4 "$VI" 2> /dev/null
    done
	netctl stop-all
    for I in $(seq -s " " 1 1 "$NB_VI") 
    do
	    VI="$VI_PREFIX$I"
    	iw dev "$VI" del
        rm /etc/netctl/"$VI"-"$SSID"
    done

    # Unset nohwcrypt=1
    modprobe -rfq ath9k
    modprobe -q ath9k

    # Restore inital values
    sysctl -q -w net.ipv6.conf.all.disable_ipv6="$IPV6" > /dev/null 
    sysctl -q -w net.ipv4.conf.all.arp_filter="$ARP" > /dev/null 
    sysctl -q -w net.core.custom_multipath="$MULTIPATH" > /dev/null 

    netctl restore
    exit 1;
}

# Check parameters
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters !"
    echo "3 parameters is needed"
    echo "1 : Number of desired interfaces"
    echo "2 : SSID of your network"
    echo "3 : Password of your network"
    exit 2;
fi

NB_VI=$1
if [ "$NB_VI" -lt 2 ] && [ "$NB_VI" -gt 11 ]; then
    echo "Please stay between 2 and 11 interfaces !"
    exit 2;
fi

# Network configuration variable
SSID=$2
WPAPWD=$3
WPAPSK=$(wpa_passphrase "$SSID" "$WPAPWD" | grep -v "#" | grep psk | cut -d'=' -f2)
VI_PREFIX=VIRT-wlan
clear

echo "##### Check system parameters #####"
if [ "$(whoami)" != "root" ]; then
        echo "Please run this script with sudo"
        exit 1
fi

# Allow Software Encryption to connect multiple virtual interface to crypted WLAN
modprobe -rfq ath9k
modprobe -q ath9k nohwcrypt=1


# Check if CONFIG_INET_DIAG_DESTROY is enable to use "ss -k"
if [ "$(grep CONFIG_INET_DIAG_DESTROY /boot/config-"$(uname -r)")" != "CONFIG_INET_DIAG_DESTROY=y" ];then
    echo "CONFIG_INET_DIAG_DESTROY need to be activate please active it and then restart the script"
    exit 1
fi

# Check packages
LIST_PKG="netctl macchanger iw ss dhcpcd"
for PKG in $LIST_PKG
do
    if  ! type "$PKG" > /dev/null ; then
        echo "Package $PKG is NOT installed! Please install it"
        exit
    fi
done

# Stop ipv6
IPV6=$(sysctl -n net.ipv6.conf.all.disable_ipv6)
sysctl -q -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null 
# Allow ARP only on the rigth interface
ARP=$(sysctl -n net.ipv4.conf.all.arp_filter)
sysctl -q -w net.ipv4.conf.all.arp_filter=1 > /dev/null 
# Start using our custom routing
MULTIPATH=$(sysctl -n net.core.custom_multipath)
sysctl -q -w net.core.custom_multipath=1 > /dev/null 

# Prevent dhcpcd to send hostname
sed -i -e 's/^hostname/#hostname/g' -e 's/^vendorclassid.*/vendorclassid/g'  /etc/dhcpcd.conf

# Stop dhcpcd
sudo systemctl stop dhcpcd

echo "##### Create virtuals interfaces #####"
# Create all the interfaces
for I in $(seq -s " " 1 1 "$NB_VI")
do
    VI="$VI_PREFIX$I"
    # Create virtual interface
    iw phy phy0 interface add "$VI" type managed
    # Change mac address to can use multiple virtual interface at the same time
    macchanger -a "$VI" > /dev/null 
    # Create the netctl's configuration file
    printf "Interface=%s\nConnection=wireless\nSecurity=wpa\nESSID=%s\nIP=dhcp\nKey=%s\n" "$VI" "$SSID" "$WPAPSK" > /etc/netctl/"$VI"-"$SSID"
done

echo "##### Stop all connexions #####"
# Delete default interface    - 

netctl store
netctl stop-all

# Connect to the AP
# Get all the IP and create table / route / rule and default route
echo "##### Connection with AP and creation of routes #####"
LIST_VI=$(seq -s " " 1 1 $((NB_VI - 1)))
for I in $LIST_VI
do
    connectVI "$I"
done

echo "##### Set default route #####"
ip route replace default$(for I in $LIST_VI ; do printf " nexthop via %s dev %s%s weight 1" "$GATEWAY" "$VI_PREFIX" "$I" ;done)

# Reset all sockets
ss -K > /dev/null

# Catch ctrl^C
trap 'stop' INT

echo "##### System ready, press any key to begin rotation  #####"
read -r none
N=0
LAST_DEL="$NB_VI"
SLEEPMAX=15
# Inifity loop
while :
do
    SLEEP=$(shuf -i1-$SLEEPMAX -n1)  
    echo "Sleep $SLEEP "
    sleep "$SLEEP"
    echo "Rotation $N begin"

    NUM=$((N % NB_VI + 1))
    DEL_VI="$VI_PREFIX""$NUM"
    DEL_IP=$(ip a show dev "$DEL_VI" | grep 'inet ' | xargs |cut -d' ' -f2 | cut -d'/' -f1)

    connectVI "$LAST_DEL"

    # Set new default route without the interface to be deleted
    LIST_VI=$(echo "$LIST_VI" | sed "s/$NUM/$LAST_DEL/g")
    ip route replace default$(for I in $LIST_VI ; do printf " nexthop via %s dev %s%s weight 1" "$GATEWAY" "$VI_PREFIX" "$I" ;done)
    
    # Reset all TCP socket to force reopen on the new route
    ss -K src = "$DEL_IP" > /dev/null
    ip rule flush table T"$NUM"

    # Release DHCP
    dhcpcd -q -k -4 "$DEL_VI"

    netctl stop "$DEL_VI"-"$SSID"
    macchanger -a "$DEL_VI" > /dev/null 
    
    LAST_DEL="$NUM"
    echo "Rotation $N end"
    N="$((N + 1))"
done

