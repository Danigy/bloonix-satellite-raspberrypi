#!/bin/bash
#
# Setup the running raspberrypi


# Source the config file
if ! /opt/bloonix-satellite-raspberrypi/source config.sh; then
  echo 'Unable to source config.sh, aborting!'
  exit 1
fi


### MAIN ###

#set -x




tput setf 2; echo -e '\n## Secure the root account - disable passwords for it'; tput sgr0

passwd -l -d root


tput setf 2; echo -e '\n## Setting timezone to UTC'; tput sgr0

export DEBCONF_NONINTERACTIVE_SEEN=true DEBIAN_FRONTEND=noninteractive
echo 'Etc/UTC' > /etc/timezone
dpkg-reconfigure tzdata


tput setf 2; echo -e '\n## Creating a 2 GB swapfile - this takes around three minutes using a Samsung EVO 32GB Class 10 SD card'; tput sgr0

if ! swapon -s | grep 'swapfile.img' 2>&1 >/dev/null; then
    test -f /var/opt/swapfile.img || dd if=/dev/zero bs=1M count=2048 of=/var/opt/swapfile.img
    chmod -v 0600 /var/opt/swapfile.img
    sync
    mkswap /var/opt/swapfile.img
    grep swap /etc/fstab || echo '/var/opt/swapfile.img none swap sw 0 0' >> /etc/fstab
    swapon -a
fi


tput setf 2; echo -e '\n## Installing packages'; tput sgr0

# Enable required contrib sources for apt-transport-https
echo -e 'deb http://mirrordirector.raspbian.org/raspbian jessie main firmware non-free\ndeb http://archive.raspberrypi.org/debian jessie main' > /etc/apt/sources.list
# Get up to date
apt-get update; apt-get -y upgrade; apt-get -y dist-upgrade
# Install required packages
apt-get -y install unattended-upgrades whois wget openvpn curl apt-transport-https raspbian-archive-keyring haveged shorewall dnsutils ntp
# Enable unattended-upgrades
echo -e 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";' > /etc/apt/apt.conf.d/20auto-upgrades
# Add docker repository, docker for ARM comes from http://blog.hypriot.com/downloads/
# the following is extracted from: curl -s https://packagecloud.io/install/repositories/Hypriot/Schatzkiste/script.deb.sh | bash
curl -L 'https://packagecloud.io/Hypriot/Schatzkiste/gpgkey' 2> /dev/null | apt-key add -
echo 'deb https://packagecloud.io/Hypriot/Schatzkiste/raspbian/ jessie main' > /etc/apt/sources.list.d/Hypriot_Schatzkiste.list
apt-get update; apt-get -y install docker-hypriot
# installation will fail, we have to reboot, then it works


tput setf 2; echo -e '\n## Set hostname (its not really required to set the hostname..)'; tput sgr0

# The AS number for the DSL the raspi is connected to
PUBLIC_IP="$(dig +short myip.opendns.com @resolver1.opendns.com)"
ORIGIN="$(whois $PUBLIC_IP | grep origin | awk '{print $2}')"
full_host_name="${ORIGIN,,}.${DOMAIN}"
hostname $full_host_name
echo "127.0.0.1 localhost
127.0.1.1 $full_host_name ${ORIGIN,,}" > /etc/hosts
echo $full_host_name > /etc/hostname

# Setup a nice PS1 so the hostname is viewd
if ! grep "^PS1" /root/.bashrc 2>&1 >/dev/null; then
    cat <<EOF >> /root/.bashrc
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\u\[\033[01;33m\]@\[\033[01;36m\]$(hostname -f) \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'
EOF
fi


tput setf 2; echo -e '\n## Setting up a cronjob to renew the bloonix satellite docker image and container'; tput sgr0

# Run the cronjobs at 00:00 on sundays (try to avoid the time of the default force-reconnect on most routers)
if ! grep bloonix /var/spool/cron/crontabs/root 2>/dev/null; then
    # Renew the renewal script weekly
    crontab -l | { cat; echo "0 0 * * 0 cd /opt/bloonix-satellite-raspberrypi/; git pull"; } | crontab -
    # Run the renewal script weekly
    crontab -l | { cat; echo "5 0 * * 0 /opt/bloonix-satellite-raspberrypi/renew-satellite-docker-container-cronjob.sh"; } | crontab -
fi

# Setup to run the renewal cronjob on every boot
echo '#!/bin/sh -e
/opt/bloonix-satellite-raspberrypi/renew-satellite-docker-container-cronjob.sh
exit 0' > /etc/rc.local



tput setf 2; echo -e '\n## Blacklisting the drivers for wlan and bluetooth'; tput sgr0

# Wlan
echo -e 'blacklist brcmfmac\nblacklist brcmutil' > /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v brcmfmac
modprobe -r -v brcmutil
# Bluetooth
echo -e 'blacklist btbcm\nblacklist hci_uart' >> /etc/modprobe.d/raspi-blacklist.conf
modprobe -r -v btbcm
modprobe -r -v hci_uart


tput setf 2; echo -e '\n## Setting up shorewall'; tput sgr0


# Shorewall concept:
#
# - OpenVPN Client
# - Allow admin SSH access from openvpn server IP via VPN
# - Allow access to bloonix satellite port from openvpn server IP via VPN
# - Allow whats required for remote checks - http, smtp, imap, ...
# - Drop everything else to private class networks
# - Allow incoming ssh from all private class outside networks

# /etc/shorewall/interfaces
echo '?FORMAT 2
red eth0        tcpflags,logmartians,nosmurfs
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

# Enable startup on boot
echo -e 'INITLOG=/dev/null
OPTIONS=""
RESTARTOPTIONS=""
SAFESTOP=0
STARTOPTIONS=""
startup=1' > /etc/default/shorewall


tput setf 2; echo -e '\n## Enabling openvpn'; tput sgr0

if ! ifconfig | grep $VPN_CLIENT_INTERFACE; then
    mv -v /root/*tar.gz /etc/openvpn/
    cd /etc/openvpn/
    tar xvzf *tar.gz
fi


tput setf 2; echo -e '\n## Setting up systemd to always spawn our Container on startup'; tput sgr0

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

# Print completed message
LOCAL_ETH_IP="$(/sbin/ifconfig eth0 | grep "inet addr" | awk '{ print $2 }' | awk -F: '{ print $2}')"
tput setf 2
echo -e "\n\n==INSTALLATION COMPLETED ================================================================================\n"
echo -e "The hostname has changed, ssh to this machine using the new hostname or the IP bound on eth0:\n"
echo -e "ssh root@$LOCAL_ETH_IP"
echo -e "\nThis machine will reboot in 60 seconds to complete the installation. Press CRTL+C to abort reboot countdown\n"
echo -e "=============================================================================================================\n"
tput sgr0

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
