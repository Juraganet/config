#!/bin/bash
# OpenVPN road warrior installer for Debian, Ubuntu and CentOS

# This script will work on Debian, Ubuntu, CentOS and probably other distros
# of the same families, although no support is offered for them. It isn't
# bulletproof but it will probably work if you simply want to setup a VPN on
# your Debian/Ubuntu/CentOS box. It has been designed to be as unobtrusive and
# universal as possible.


# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -qs "dash"; then
	echo "This script needs to be run with bash, not sh"
	exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 2
fi

if [[ ! -e /dev/net/tun ]]; then
	echo "The TUN device is not available
You need to enable TUN before running this script"
	exit 3
fi

if grep -qs "CentOS release 5" "/etc/redhat-release"; then
	echo "CentOS 5 is too old and not supported"
	exit 4
fi
if [[ -e /etc/debian_version ]]; then
	OS=debian
	GROUPNAME=nogroup
	RCLOCAL='/etc/rc.local'
elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
	OS=centos
	GROUPNAME=nobody
	RCLOCAL='/etc/rc.d/rc.local'
else
	echo "Looks like you aren't running this installer on Debian, Ubuntu or CentOS"
	exit 5
fi

newclient () {
	# Generates the custom client.ovpn
	cp /etc/openvpn/client-common.txt ~/$1.ovpn
	echo "<ca>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/ca.crt >> ~/$1.ovpn
	echo "</ca>" >> ~/$1.ovpn
	echo "<cert>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/issued/$1.crt >> ~/$1.ovpn
	echo "</cert>" >> ~/$1.ovpn
	echo "<key>" >> ~/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/private/$1.key >> ~/$1.ovpn
	echo "</key>" >> ~/$1.ovpn
	echo "<tls-auth>" >> ~/$1.ovpn
	cat /etc/openvpn/ta.key >> ~/$1.ovpn
	echo "</tls-auth>" >> ~/$1.ovpn
	cip=$( tail -n 1 /etc/openvpn/ip )
	if [[ "$cip" = "254" ]]; then
		echo "10" > /etc/openvpn/ip
	fi
	cip=$(( $cip + 1 ))
	echo "ifconfig-push 10.8.0.$cip 255.255.255.0" > /etc/openvpn/ccd/$1
	if pgrep firewalld; then
		IP=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s 10.8.0.0/24 -j SNAT --to ' | cut -d " " -f 7)
		firewall-cmd --zone=public --add-port=$2/tcp
		firewall-cmd --permanent --zone=public --add-port=$2/tcp
		firewall-cmd --direct --add-rule ipv4 nat PREROUTING 0 -d $IP -p tcp --dport $2 -j DNAT --to-destination 10.8.0.$cip:$2
		firewall-cmd --permanent --direct --add-rule ipv4 nat PREROUTING 0 -d $IP -p tcp --dport $2 -j DNAT --to-destination 10.8.0.$cip:$2
		firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -d 10.8.0.$cip -p tcp --dport $2 -j SNAT --to-source 10.8.0.1
		firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -d 10.8.0.$cip -p tcp --dport $2 -j SNAT --to-source 10.8.0.1
    	else
    		IP=$(grep 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to ' $RCLOCAL | cut -d " " -f 11)
    		iptables -t nat -A PREROUTING -d $IP -p tcp --dport $2 -j DNAT --to-destination 10.8.0.$cip:$2
		iptables -t nat -A POSTROUTING -d 10.8.0.$cip -p tcp --dport $2 -j SNAT --to-source 10.8.0.1
		iptables -A INPUT -p tcp --dport $2 -j ACCEPT
		sed -i "1 a\iptables -t nat -A PREROUTING -d $IP -p tcp --dport $2 -j DNAT --to-destination 10.8.0.$cip:$2" $RCLOCAL
		sed -i "1 a\iptables -t nat -D PREROUTING  -d $IP -p tcp --dport $2 -j DNAT --to-destination 10.8.0.$cip:$2" /etc/openvpn/deliptables
		sed -i "1 a\iptables -t nat -A POSTROUTING -d 10.8.0.$cip -p tcp --dport $2 -j SNAT --to-source 10.8.0.1" $RCLOCAL
		sed -i "1 a\iptables -t nat -D POSTROUTING -d 10.8.0.$cip -p tcp --dport $2 -j SNAT --to-source 10.8.0.1" /etc/openvpn/deliptables
		sed -i "1 a\iptables -D INPUT -p tcp --dport $2 -j ACCEPT" /etc/openvpn/deliptables
		sed -i "1 a\iptables -A INPUT -p tcp --dport $2 -j ACCEPT" $RCLOCAL
	fi
	echo "$cip" >> /etc/openvpn/ip
	echo "10.8.0.$cip" > /etc/openvpn/cip/$1
	echo "$2" > /etc/openvpn/ports/$1
	echo "$2" >> /etc/openvpn/cport
}

# Try to get our IP from the system and fallback to the Internet.
# I do this to make the script compatible with NATed servers (lowendspirit.com)
# and to avoid getting an IPv6.
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
		IP=$(wget -4qO- "http://whatismyip.akamai.com/")
fi

if [[ -e /etc/openvpn/server.conf ]]; then
	while :
	do
	clear
		echo "Looks like OpenVPN is already installed"
		echo ""
		echo "What do you want to do?"
		echo "   1) Add a new user"
		echo "   2) Revoke an existing user"
		echo "   3) Exit"
		read -p "Select an option [1-4]: " option
		case $option in
			1) 
			echo ""
			echo "Tell me a name for the client certificate"
			echo "Please, use one word only, no special characters"
			read -p "Client name: " -e -i client CLIENT
			cport=$( tail -n 1 /etc/openvpn/cport )
			cport=$(( $cport + 1 ))
			echo "Port forwarding IP?"
			read -p "Port ($cport-5000): " -e -i $cport PORT
			cd /etc/openvpn/easy-rsa/
			./easyrsa build-client-full $CLIENT nopass
			# Generates the custom client.ovpn
			newclient "$CLIENT" "$PORT"
			echo ""
			echo "Client $CLIENT added, configuration is available at" ~/"$CLIENT.ovpn"
			exit
			;;
			2)
			# This option could be documented a bit better and maybe even be simplimplified
			# ...but what can I say, I want some sleep too
			NUMBEROFCLIENTS=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep -c "^V")
			if [[ "$NUMBEROFCLIENTS" = '0' ]]; then
				echo ""
				echo "You have no existing clients!"
				exit 6
			fi
			echo ""
			echo "Select the existing client certificate you want to revoke"
			tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | nl -s ') '
			if [[ "$NUMBEROFCLIENTS" = '1' ]]; then
				read -p "Select one client [1]: " CLIENTNUMBER
			else
				read -p "Select one client [1-$NUMBEROFCLIENTS]: " CLIENTNUMBER
			fi
			CLIENT=$(tail -n +2 /etc/openvpn/easy-rsa/pki/index.txt | grep "^V" | cut -d '=' -f 2 | sed -n "$CLIENTNUMBER"p)
			cd /etc/openvpn/easy-rsa/
			./easyrsa --batch revoke $CLIENT
			./easyrsa gen-crl
			rm -rf pki/reqs/$CLIENT.req
			rm -rf pki/private/$CLIENT.key
			rm -rf pki/issued/$CLIENT.crt
			rm -rf /etc/openvpn/crl.pem
			cp /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn/crl.pem
			# CRL is read with each client connection, when OpenVPN is dropped to nobody
			chown nobody:$GROUPNAME /etc/openvpn/crl.pem
			echo ""
			echo "Certificate for client $CLIENT revoked"
			cport=$( cat /etc/openvpn/ports/$CLIENT )
			ccip=$( cat /etc/openvpn/cip/$CLIENT )
			if pgrep firewalld; then
				IP=$(firewall-cmd --direct --get-rules ipv4 nat POSTROUTING | grep '\-s 10.8.0.0/24 -j SNAT --to ' | cut -d " " -f 7)
				firewall-cmd --direct --remove-rule ipv4 nat PREROUTING 0 -d $IP -p tcp --dport $cport -j DNAT --to-destination $ccip:$cport
				firewall-cmd --permanent --direct --remove-rule ipv4 nat PREROUTING 0 -d $IP -p tcp --dport $cport -j DNAT --to-destination $ccip:$cport
				firewall-cmd --direct --remove-rule ipv4 nat POSTROUTING 0 -d $ccip -p tcp --dport $cport -j SNAT --to-source 10.8.0.1
				firewall-cmd --permanent --direct --remove-rule ipv4 nat POSTROUTING 0 -d $ccip -p tcp --dport $cport -j SNAT --to-source 10.8.0.1
				firewall-cmd --zone=public --remove-port=$cport/tcp
				firewall-cmd --permanent --zone=public --remove-port=$cport/tcp
			else
		    	IP=$(grep 'iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to ' $RCLOCAL | cut -d " " -f 11)
		    		iptables -t nat -D PREROUTING -d $IP -p tcp --dport $cport -j DNAT --to-destination $ccip:$cport
				iptables -t nat -D POSTROUTING -d $ccip -p tcp --dport $cport -j SNAT --to-source 10.8.0.1
				sed -i "/iptables -t nat -A PREROUTING -d $IP -p tcp --dport $cport -j DNAT --to-destination $ccip:$cport/d" $RCLOCAL
				sed -i "/iptables -t nat -A POSTROUTING -d $ccip -p tcp --dport $cport -j SNAT --to-source 10.8.0.1/d" $RCLOCAL
				sed -i "/iptables -t nat -A INPUT -p tcp --dport $cport -j ACCEPT/d" $RCLOCAL
				iptables -D INPUT -p tcp --dport $cport -j ACCEPT
			fi
			rm /etc/openvpn/ccd/$CLIENT
			cip=$(cat /etc/openvpn/cip/$CLIENT | cut -d '.' -f 4)
			sed -i "/$cip/d" /etc/openvpn/ip
			sed -i "/$cport/d" /etc/openvpn/cport
			rm /etc/openvpn/ports/$CLIENT
			echo "Port forwarding $CLIENT $ccip:$cport removed"
			exit
			;;
			3) exit;;
		esac
	done
else
	clear
	echo 'OpenVPN not installed!'
fi
