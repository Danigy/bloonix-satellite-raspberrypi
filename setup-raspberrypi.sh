#!/bin/bash
#
# Setup the running raspberrypi

## Login and lock root account ##
#
# ssh-copy-id root@minibian  # pw raspberry
# ssh root@minibian
# scp *-vpn-AS*.example.com.tar.gz root@minibian:
# Install any additional ssh keys on minibian


# Enter the satellite authkey provided by Blunix GmbH
SATELLITE_AUTHKEY='secret_longer_than_32_characters_bloonix_satellite_authkey'


## Secure the root account
passwd -l -d root


## Create a 4 GB swapfile
touch /var/opt/swapfile.img; chmod 0600 /var/opt/swapfile.img
dd if=/dev/zero bs=1M count=4096 of=/var/opt/swapfile.img
mkswap /var/opt/swapfile.img
grep swap /etc/fstab || echo '/var/opt/swapfile.img none swap sw 0 0' >> /etc/fstab
swapon -a


## Set hostname (its not really required to set the hostname..)
current_public_ip="$(wget http://ipinfo.io/ip -qO -)"
#domain='example.sat.com'
#host_part="$(whois ${current_public_ip} | grep origin | awk '{print $2}')"
#full_host_name="${host_part}.$domain"
#hostname $full_host_name
#sed '/127.0.0.1/d' /etc/hosts
#echo "127.0.0.1 $full_host_name $host_part" >> /etc/hosts
#echo $full_host_name > /etc/hostname


## Packages

# Enable required contrib sources for apt-transport-https
echo -e 'deb http://mirrordirector.raspbian.org/raspbian jessie main firmware non-free\ndeb http://archive.raspberrypi.org/debian jessie main' > /etc/apt/sources.list
# Get up to date
apt-get update; apt-get -y upgrade; apt-get -y dist-upgrade
# Install required packages
apt-get -y install unattended-upgrades whois wget openvpn curl apt-transport-https raspbian-archive-keyring haveged shorewall
# Enable unattended-upgrades
echo -e 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
# Add docker repository, docker for ARM comes from http://blog.hypriot.com/downloads/
# the following is extracted from: curl -s https://packagecloud.io/install/repositories/Hypriot/Schatzkiste/script.deb.sh | bash
curl -L 'https://packagecloud.io/Hypriot/Schatzkiste/gpgkey' 2> /dev/null | apt-key add -
echo 'deb https://packagecloud.io/Hypriot/Schatzkiste/raspbian/ jessie main' > /etc/apt/sources.list.d/Hypriot_Schatzkiste.list
apt-get update; apt-get -y install docker-hypriot
# installation will fail, we have to reboot, then it works


## Setup cronjob to renew docker image
# At 00:00 on sundays (try to avoid the time of the default force-reconnect on most routers)
crontab -l | { cat; echo "0 0 * * 0 /usr/local/sbin/renew-bloonix-satellite-container.sh"; } | crontab -

## Blacklist the drivers for wlan and bluetooth
# Wlan
echo -e 'blacklist brcmfmac\nblacklist brcmutil' > /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v brcmfmac
modprobe -r -v brcmutil
# Bluetooth
echo -e 'blacklist btbcm\nblacklist hci_uart' >> /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v btbcm
modprobe -r -v hci_uart


# TODO other basics?


## Setup shorewall

# Enable startup on boot
echo -e 'INITLOG=/dev/null\nOPTIONS=""\nRESTARTOPTIONS=""\nSAFESTOP=0\nSTARTOPTIONS=""\nstartup=1' >> /etc/default/shorewall


## /etc/shorewall/interfaces
?FORMAT 2

red eth0        tcpflags,logmartians,nosmurfs
red wlan0       tcpflags,logmartians,nosmurfs
sat tun0        tcpflags


## /etc/shorewall/policy
$FW     all     ACCEPT  -       -
sat     $FW     ACCEPT  -       -
all     all     REJECT  -       -


## /etc/shorewall/rules
?SECTION ALL
?SECTION ESTABLISHED
?SECTION RELATED
?SECTION INVALID
?SECTION UNTRACKED
?SECTION NEW

SSH(ACCEPT)     red     $FW
ACCEPT          all     $FW     tcp     5464
DNS(ACCEPT)     $FW     all
DROP            $FW     red:10.0.0.0/8,172.16.0.0/12,192.168.0.0/16


## /etc/shorewall/zones
fw      firewall
red
sat





## Enable openvpn
mv /root/*tar.gz /etc/openvpn/; cd /etc/openvpn/; tar xvzf *tar.gz


## Print statistics relevant for us (provider numbers and so on)
echo -e "=============================================================================================================\n"
echo -e "\nINSTALLATION COMPLETED\n\n\n"
echo -e "Please send the following sensitive information to Blunix GmbH:\n"




# Sleep and while and then reboot for the kernel changes to take effect
sleep 20
shutdown -r now



exit 0
