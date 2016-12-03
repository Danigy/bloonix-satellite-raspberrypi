#!/bin/bash
#
# Create the minibian image on your laptop

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

