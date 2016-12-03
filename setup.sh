#!/bin/bash
#
# Setup the running raspberrypi


### PLEASE CHANGE THOSE VARIABLES ###

# Enter the satellite authkey provided by Blunix GmbH
SATELLITE_AUTHKEY='secret_longer_than_32_characters_bloonix_satellite_authkey'

# Setup data about the VPN server that is used to forward requests to this Raspberry Pi
VPN_SERVER_IP='123.123.123.123'
VPN_SERVER_PORT='1194'
VPN_SERVER_INTERNAL_IP='10.10.0.1'




### MAIN ###

#set -x


echo '## Secure the root account - disable passwords for it'

passwd -l -d root


echo '## Createing a 4 GB swapfile, this takes around 3 minutes'

test -f /var/opt/swapfile.img || dd if=/dev/zero bs=1M count=4096 of=/var/opt/swapfile.img
chmod 0600 /var/opt/swapfile.img
mkswap /var/opt/swapfile.img
grep swap /etc/fstab || echo '/var/opt/swapfile.img none swap sw 0 0' >> /etc/fstab
swapon -a


#echo '## Set hostname (its not really required to set the hostname..)'

current_public_ip="$(wget http://ipinfo.io/ip -qO -)"
#domain='example.sat.com'
origin="$(whois ${current_public_ip} | grep origin | awk '{print $2}')"
host_part=$origin
#full_host_name="${host_part}.$domain"
#hostname $full_host_name
#sed '/127.0.0.1/d' /etc/hosts
#echo "127.0.0.1 $full_host_name $host_part" >> /etc/hosts
#echo $full_host_name > /etc/hostname


echo '## Installing packages'

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


echo '## Setting up a cronjob to renew the bloonix satellite docker image and container'

# At 00:00 on sundays (try to avoid the time of the default force-reconnect on most routers)
wget https://raw.githubusercontent.com/satellitesharing/bloonix-satellite-dsl-client/master/renew-satellite-docker-container-cronjob.sh -O /usr/local/sbin/renew-satellite-docker-container.sh
grep 'renew-satellite-docker-container' /var/spool/cron/crontabs/root || crontab -l | { cat; echo "0 0 * * 0 /usr/local/sbin/renew-satellite-docker-container.sh"; } | crontab -


echo '## Blacklisting the drivers for wlan and bluetooth'

# Wlan
echo -e 'blacklist brcmfmac\nblacklist brcmutil' > /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v brcmfmac
modprobe -r -v brcmutil
# Bluetooth
echo -e 'blacklist btbcm\nblacklist hci_uart' >> /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v btbcm
modprobe -r -v hci_uart


echo '## Setting up shorewall'

# Enable startup on boot
echo -e 'INITLOG=/dev/null\nOPTIONS=""\nRESTARTOPTIONS=""\nSAFESTOP=0\nSTARTOPTIONS=""\nstartup=1' >> /etc/default/shorewall

# /etc/shorewall/interfaces
'echo ?FORMAT 2

red eth0        tcpflags,logmartians,nosmurfs
red wlan0       tcpflags,logmartians,nosmurfs
sat tun0        tcpflags' > /etc/shorewall/interfaces

# /etc/shorewall/policy
echo '$FW     all     ACCEPT  -       -
sat     $FW     ACCEPT  -       -
all     all     REJECT  -       -' > /etc/shorewall/policy

# /etc/shorewall/rules
echo '?SECTION ALL
?SECTION ESTABLISHED
?SECTION RELATED
?SECTION INVALID
?SECTION UNTRACKED
?SECTION NEW

SSH(ACCEPT)     red     $FW
ACCEPT          all     $FW     tcp     5464
DNS(ACCEPT)     $FW     all
DROP            $FW     red:10.0.0.0/8,172.16.0.0/12,192.168.0.0/16' > /etc/shorewall/rules

# /etc/shorewall/zones
echo 'fw      firewall
red
sat' > /etc/shorewall/zones


echo '## Enabling openvpn'
if ifconfig | grep tun; then
    mv -v /root/*tar.gz /etc/openvpn/
    cd /etc/openvpn/
    tar xvzf *tar.gz
fi


echo '## Setting up systemd to always spawn our Container on startup'

# Create a systemd config file
echo '[Unit]
Description=Bloonix Satellite Docker Container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a BloonixSatellite
ExecStop=/usr/bin/docker stop -t 2 BloonixSatellite

[Install]
WantedBy=default.target' > /etc/systemd/system/docker-bloonix-satellite.service

# Reload systemd
systemctl daemon-reload



### END ###

# Print statistics relevant for us (provider numbers and so on)
echo -e "=============================================================================================================\n"
echo -e "\nINSTALLATION COMPLETED\n\n\n"
echo -e "Please send the following sensitive information to Blunix GmbH:\n"
echo -e "Origin: $origin\n\n"
echo -e "This machine will reboot in 60 seconds to complete the installation. Press CRTL+C to abort.\n"
echo -e "=============================================================================================================\n"

# Sleep and while and then reboot for the kernel changes to take effect
secs=60
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
shutdown -r now &


# Exit gracefully
exit 0
