#!/bin/sh

### BEGIN INIT INFO
# Provides:          firewall 
# Required-Start:    $network $syslog 
# Required-Stop:     $network $syslog
# Should-Start:      
# Should-Stop:       
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop firewall
# Description: Iptables firewall      
# 

### END INIT INFO

# Declare some variables first

# Set PATH

PATH=/sbin:/bin:/usr/sbin:/usr/bin

#PORTS
PORTS1="20,21,22,23,25,53,67,68,80,110,113,123,135,137"
PORTS2="138,139,143,389,443,445,465,507,587,631,993,995,1433,3268"
PORTS3="5000,5030,8080,6665,6666,6667,6668,6669,6670,11371"

# Declare internet ip & i-face

INET_IFACE="eth0"
INET_IP="163.172.81.92"

# Declare localhost ip & i-face

LO_IFACE="lo"
LO_IP="127.0.0.1"

# Declare ppp ip, i-face & ip range

PPP_IFACE="tap_vpn"
PPP_IP="10.130.30.1"
PPP_IP_RANGE="10.130.30.0/24"

# Path to iptables executable

IPTABLES="/sbin/iptables"

case "$1" in
    start)
	# Set the default policy to drop everything which is not exactly declared to be allowed

	$IPTABLES -P INPUT DROP
	$IPTABLES -P OUTPUT DROP
	$IPTABLES -P FORWARD ACCEPT

	
	# The INPUT chain
	# Allow ICMP on the internet ip addresses as required by some RFC's
	$IPTABLES -A INPUT -p ICMP -i $INET_IFACE -j ACCEPT

    # Open OpenVPN and Softether ports
    $IPTABLES -A INPUT -p TCP -d $INET_IP --dport 995 -j ACCEPT
    $IPTABLES -A INPUT -p TCP -d $INET_IP --dport 443 -j ACCEPT
    $IPTABLES -A INPUT -p TCP -d $INET_IP --dport 5555 -j ACCEPT
    $IPTABLES -A INPUT -p UDP -d $INET_IP --dport 1194 -j ACCEPT
    $IPTABLES -A INPUT -p TCP -d $INET_IP --dport 1194 -j ACCEPT
    $IPTABLES -A INPUT -p UDP -d $INET_IP --dport 1701 -j ACCEPT
    # Open ftp port on external ip address
    #$IPTABLES -A INPUT -p TCP -d $INET_IP --dport 21 -j ACCEPT

	# Open ssh port on external ip address
	$IPTABLES -A INPUT -p TCP -d $INET_IP --dport 22 -j ACCEPT

    # Open L2TP/IPSec on external ip address
    $IPTABLES -A INPUT -p UDP -d $INET_IP --dport 500 -j ACCEPT
    $IPTABLES -A INPUT -p UDP -d $INET_IP --dport 4500 -j ACCEPT
	$IPTABLES -A INPUT -p 50 -d $INET_IP -j ACCEPT
	$IPTABLES -A INPUT -m policy --dir in --pol ipsec -p UDP -d $INET_IP --dport 1701 -j ACCEPT
	
	# Allow localhost ip to access localhost i-face
	$IPTABLES -A INPUT -p ALL -i $LO_IFACE -s $LO_IP -j ACCEPT

	# Accept established and related packets
	$IPTABLES -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

	# Allow ppp ip range to ping ppp ip
	$IPTABLES -A INPUT -p ICMP -s $PPP_IP_RANGE -d $PPP_IP -j ACCEPT

	# Allow ppp ip range to use DNS from ppp ip
	$IPTABLES -A INPUT -p TCP -s $PPP_IP_RANGE -d $PPP_IP --dport 53 -j ACCEPT
	$IPTABLES -A INPUT -p UDP -s $PPP_IP_RANGE -d $PPP_IP --dport 53 -j ACCEPT
	$IPTABLES -A INPUT -p TCP -s $PPP_IP_RANGE -d $INET_IP --dport 53 -j ACCEPT
  $IPTABLES -A INPUT -p UDP -s $PPP_IP_RANGE -d $INET_IP --dport 53 -j ACCEPT

	# The FORWARD chain

	$IPTABLES -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1326

  # Block vpn clients to see each other
  $IPTABLES -A FORWARD -p all -s $PPP_IP_RANGE -d $PPP_IP_RANGE -j DROP
  
  # Block smtp traffic for pptpd clients
  $IPTABLES -A FORWARD -i $PPP_IFACE -o $INET_IFACE -s $PPP_IP_RANGE -p tcp -m multiport --dports 25,465,587 -j DROP
	

	# Nat pptpd clients
	$IPTABLES -A FORWARD -i $PPP_IFACE -o $INET_IFACE -s $PPP_IP_RANGE -p ICMP -j ACCEPT
	
	# Block torrent test
	$IPTABLES -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string ".torrent" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "torrent" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "announce" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "info_hash" -j DROP
	$IPTABLES -A FORWARD -m string --algo bm --string "BitTorrent_protocol" -j DROP
	
	# DHT keyword
	iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
	iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
	iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP

	## Trying forward
	iptables -A FORWARD -i $PPP_IFACE -o $INET_IFACE -p tcp -m multiport --dport 6881:6889 -j DROP
	iptables -A FORWARD -i $PPP_IFACE -o $INET_IFACE -p udp -m multiport --dport 1024:65534 -j DROP

        # Accept established and related packets
        $IPTABLES -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
	
	
	# The OUTPUT chain

	# Allow access for localhost ip 
	$IPTABLES -A OUTPUT -p ALL -s $LO_IP -j ACCEPT

        # Allow access for external ip
        $IPTABLES -A OUTPUT -p ALL -s $INET_IP -j ACCEPT

	# Allow access for ppp ip
	$IPTABLES -A OUTPUT -p ALL -s $PPP_IP -j ACCEPT
	
	# Allow everything going out the internet i-face
	$IPTABLES -A OUTPUT -p ALL -o $INET_IFACE -j ACCEPT

	# Accept established and related packets
	$IPTABLES -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

	# NAT table

	# The POSTROUTING chain

	# Log everything in nat
        $IPTABLES -t nat -A POSTROUTING -p all -o $INET_IFACE -j ULOG --ulog-nlgroup 1

	# Nat pptpd clients
	# Auto generated SNAT
	#/scripts/nat-firewall.sh

	# Default SNAT for all other
	$IPTABLES -t nat -A POSTROUTING -p all -o $INET_IFACE -s $PPP_IP_RANGE -j SNAT --to-source $INET_IP
  ;;

    stop)

	# Clear any rules applied before this script was called
	$IPTABLES -P INPUT ACCEPT
	$IPTABLES -P FORWARD ACCEPT
	$IPTABLES -P OUTPUT ACCEPT

	# Reset the default policies in the nat table.
	$IPTABLES -t nat -P PREROUTING ACCEPT
	$IPTABLES -t nat -P POSTROUTING ACCEPT
	$IPTABLES -t nat -P OUTPUT ACCEPT

	# Reset the default policies in the mangle table.
	$IPTABLES -t mangle -P PREROUTING ACCEPT
	$IPTABLES -t mangle -P OUTPUT ACCEPT

	# Flush all the rules in the filter and nat tables.
	$IPTABLES -F
	$IPTABLES -t nat -F
	$IPTABLES -t mangle -F

	# Erase all chains that's not default in filter and nat table.

	$IPTABLES -X
	$IPTABLES -t nat -X
	$IPTABLES -t mangle -X
    ;;


    restart)

	$0 stop
	$0 start
    ;;

    status)
	$IPTABLES -L -n
    ;;

    *)
	log_action_msg "Usage: /etc/init.d/iptables {start|stop|restart|status}"
	exit 1
    ;;
esac

exit 0
