## Bloonix Satellite Installation Instructions for Raspberry Pi 3 Model B


This manual explains how to install Bloonix Satellite with Docker on the Raspberry Pi Model B.


### 1) Install minibian to a micro SD Card

Insert the Micro SD Card into your Laptop and use the following command to determine the name of the new device:

```
$ dmesg -T
[...]
[timestamp] mmc0: new ultra high speed SDR104 SDHC card at address 0001
[timestamp] mmcblk0: mmc0:0001 00000 29.8 GiB 
[timestamp] mmcblk0: p1 p2

$ sudo fdisk -l /dev/mmcblk0
Disk /dev/mmcblk0: 32.0 GB, 32010928128 bytes
[...]
```

Go to [sourceforge.net/projects/minibian](https://sourceforge.net/projects/minibian/), download the latest minibian image and
unpack the archive.  Write the minibian image to the SD card:
```
# Replace with filename of latest image
sudo dd if=2016-03-12-jessie-minibian.img | pv | dd of=/dev/mmcblk0
sudo sync
sudo partprobe
```

These commands will resize the root partition on the SD card to the maximum available space
```
# Set this to your SD card device
SD_CARD_DEVICE_FILE='/dev/mmcblk0'
start_sector=$(sudo fdisk -l ${SD_CARD_DEVICE_FILE} | grep ${SD_CARD_DEVICE_FILE}p2 |  awk '{ print $2 }')
echo -e "d\n2\nn\np\n2\n${start_sector}\n\nw" | sudo fdisk ${SD_CARD_DEVICE_FILE}
sudo sync
sudo e2fsck -f ${SD_CARD_DEVICE_FILE}p2
sudo resize2fs ${SD_CARD_DEVICE_FILE}p2
```


### 2) Setup SSH to the Raspberry Pi

Copy your SSH public key to the Raspberry Pi - the password is "raspberry" by default
```
ssh-copy-id root@minibian
```

Copy over any files required later
```
scp vpn-archive.tar.gz root@minibian:
[...]
```


### 3) Install docker and the Bloonix Satellite service on the Raspberry Pi

Login to the Raspberry Pi, then download and execute the installation script:

```
ssh root@minibian
wget https://raw.githubusercontent.com/satellitesharing/bloonix-satellite-dsl-client/master/setup.sh
```


### 4) Setup your router for the Raspberry Pi

Common routers like AVM Fritz Box:  
The Raspberry Pi should be connected to a network where it can not reach the other computers. Most common routers, like
RVM Fritz Box'es, provide the option to assign one lan network port to a "guest network", which cant reach the other
networks. Thats what you want to set up, however make sure that nobody else (no house guests) use that network. Also
check if the guest wlan provided by your Fritz Box or router allows interactions to and from the guest LAN network.

More expensive routers:  
If you can setup a prover VLAN, thats even better. 


Note:  
The setup script disables wlan and bluetooth and the Raspberry Pi by unloading and blacklisting the drivers.
You are hence only access the device via SSH if you are in the same LAN network.


After the Raspberry Pi is attached to a secure LAN port the installation is finished.
