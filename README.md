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
$ sudo dd if=2016-03-12-jessie-minibian.img | pv | dd of=/dev/mmcblk0
1626112+0 records in
1626112+0 records out
832569344 bytes (833 MB) copied, 107.735 s, 7.7 MB/s

$ sudo sync
$ sudo partprobe
```

These commands will resize the root partition on the SD card to the maximum available space. Copy paste them to the terminal on your Laptop - make sure to set the first variable according to your SD Cards device file name!
```bash
# Set this to your SD card device!
SD_CARD_DEVICE_FILE='/dev/mmcblk0'
start_sector=$(sudo fdisk -l ${SD_CARD_DEVICE_FILE} | grep ${SD_CARD_DEVICE_FILE}p2 |  awk '{ print $2 }')
echo -e "d\n2\nn\np\n2\n${start_sector}\n\nw" | sudo fdisk ${SD_CARD_DEVICE_FILE}
sudo sync
sudo e2fsck -f ${SD_CARD_DEVICE_FILE}p2
sudo resize2fs ${SD_CARD_DEVICE_FILE}p2
```

Expected output:
```
$ SD_CARD_DEVICE_FILE='/dev/mmcblk0'
$ start_sector=$(sudo fdisk -l ${SD_CARD_DEVICE_FILE} | grep ${SD_CARD_DEVICE_FILE}p2 |  awk '{ print $2 }')
$ echo -e "d\n2\nn\np\n2\n${start_sector}\n\nw" | sudo fdisk ${SD_CARD_DEVICE_FILE}
Command (m for help): Partition number (1-4): 
Command (m for help): Partition type:
   p   primary (1 primary, 0 extended, 3 free)
   e   extended
Select (default p): Partition number (1-4, default 2): First sector (125056-62521343, default 125056): Last sector, +sectors or +size{K,M,G} (125056-62521343, default 62521343): Using default value 62521343
Command (m for help): The partition table has been altered!
Calling ioctl() to re-read partition table.
Syncing disks.

$ sudo sync
$ sudo e2fsck -f ${SD_CARD_DEVICE_FILE}p2
e2fsck 1.42.9 (4-Feb-2014)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
/dev/mmcblk0p2: 15631/46944 files (0.2% non-contiguous), 120088/187512 blocks

$ sudo resize2fs ${SD_CARD_DEVICE_FILE}p2
resize2fs 1.42.9 (4-Feb-2014)
Resizing the filesystem on /dev/mmcblk0p2 to 7799536 (4k) blocks.
The filesystem on /dev/mmcblk0p2 is now 7799536 blocks long.
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
