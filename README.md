### Create the minibian image on your laptop ###

# Set device to use as sd card for the rapsi
sd_card_device=/dev/mmcblk0

# Minibian is used as image: https://sourceforge.net/projects/minibian/
wget https://sourceforge.net/projects/minibian/TODO

# Flash to micro SD Card
dd if=2016-03-12-jessie-minibian.img | pv | dd of=$sd_card_device

# Resize the root partition to maximum available space
start_sector=$(sudo fdisk -l ${sd_card_device} | grep ${sd_card_device}p2 |  awk '{ print $2 }')
echo -e "d\n2\nn\np\n2\n${start_sector}\n\nw" | fdisk ${sd_card_device}
sync
e2fsck -f ${sd_card_device}/p2
resize2fs ${sd_card_device}/p2




### Setup Script ###

## Login and lock root account
ssh-copy-id root@minibian  # pw raspberry
ssh root@minibian
passwd -l -d root
scp -v blunix-dsl-monitoring-vpn-AS3320.dsl.sat.pm.tar.gz root@minibian:
# Install customer ssh keys now


## Packages
# Enable required contrib sources for apt-transport-https
echo -e 'deb http://mirrordirector.raspbian.org/raspbian jessie main firmware non-free\ndeb http://archive.raspberrypi.org/debian jessie main' > /etc/apt/sources.list
# Get up to date
apt-get update; apt-get -y upgrade; apt-get -y dist-upgrade
# Install required packages
apt-get -y install unattended-upgrades whois wget openvpn curl apt-transport-https raspbian-archive-keyring nano
# Add docker repository, docker for ARM comes from http://blog.hypriot.com/downloads/
# the following is extracted from: curl -s https://packagecloud.io/install/repositories/Hypriot/Schatzkiste/script.deb.sh | bash
curl -L 'https://packagecloud.io/Hypriot/Schatzkiste/gpgkey' 2> /dev/null | apt-key add -
echo 'deb https://packagecloud.io/Hypriot/Schatzkiste/raspbian/ jessie main' > /etc/apt/sources.list.d/Hypriot_Schatzkiste.list
apt-get update; apt-get -y install docker-hypriot

## Set hostname
current_public_ip="$(wget http://ipinfo.io/ip -qO -)"
host_part="$(whois ${current_public_ip} | grep origin | awk '{print $2}')"
full_host_name="${host_part}.sat.pm"
hostname $full_host_name
sed '/127.0.0.1/d' /etc/hosts
echo "127.0.0.1 $full_host_name $host_part" >> /etc/hosts
echo $full_host_name > /etc/hostname

# other basics?


## Enable openvpn
mv /root/*tar.gz /etc/openvpn/; cd /etc/openvpn/; tar xvzf *tar.gz
service openvpn restart



## Disable wifi and bluetooth
http://www.raspberrypi-spy.co.uk/2015/06/how-to-disable-wifi-power-saving-on-the-raspberry-pi/
https://www.raspberrypi.org/forums/viewtopic.php?f=63&t=138610


2) Setup shorewall







4) Start docker in ready only - the customer gets a unique satellite authkey


5) Setup cronjob to renew docker image


5) Setup VPN



6) If installed by blunix:
  - disable password auth



7) Print statistics relevant for us (provider numbers and so on)


