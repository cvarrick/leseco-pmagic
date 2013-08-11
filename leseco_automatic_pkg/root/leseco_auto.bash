#!/bin/bash
#Copyright (C) 2012, Lower East Side Ecology Center

#This program is free software; you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation; either version 3 of the License, or
#(at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program. If not, see http://www.gnu.org/licenses/.

#TODO
#Description TK
VERSION="0.1"

#Floor values 
#cpu speed in Mhz 
cpu_floor=2000

#Memory size in kB
mem_floor=1500000

#Disk size in GB
disk_floor=120

banner="###############################################################################"
echoWarning() {
	echo -e "\e[05;33;41m${banner}\e[00m"
	echo -e "\e[01;33;41m${1}\e[00m"
	echo -e "\e[05;33;41m${banner}\e[00m"
}

echoBoldGreen() {
	echo -e "\e[01;32m${1}\e[00m"
}

clear
echo "Starting $0 version $VERSION in Auto Mode"
MNT_DIR="mnt"

NET_UP=0
while [ $NET_UP == 0 ]
do
	#TODO make interface more general
        echo "Waiting for network..."
        IP=$(ifconfig eth0 | grep 'inet addr' | awk '{ print $2 }' | cut -f2 -d: )
        if [ $(echo $IP | grep "10\.0\.0\.[0-9]*") ]; then
                NET_UP=1
        else
        sleep 3
        fi
done
echo "Network up - ip is $IP"
clear

MAC=$(ifconfig eth0 | grep -o -E '([[:xdigit:]]{1,2}:){5}[[:xdigit:]]{1,2}' | sed 's/://g')

MANUFACTURER=$(dmidecode -s system-manufacturer |grep -v ^#|sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/ /_/g' )

MODEL=$(dmidecode -s system-product-name |grep -v ^# |sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/ /_/g')

SERIAL=$(dmidecode -s system-serial-number |grep -v ^# |sed -e 's/^[ \t]*//' -e 's/[ \t]*$//' -e 's/ /_/g')

OUTPUT_DIR=@${MANUFACTURER}~${MODEL}~${SERIAL}~${IP}

mkdir -pv "$OUTPUT_DIR"

####################################
# Run hardinfo
# TODO - this is temporary
###################################

lshw -html > ${OUTPUT_DIR}/lshw.html

echoBoldGreen "System Information"
model=$(dmidecode -q -t 1|grep -E -v "^System Information|Handle|Wake-up|Not Specified|Unknown|:[ ]*$|^$")
echo "$model"

echoBoldGreen "Processor(s)"
cpu=$(dmidecode  -q -t 4 |grep -E "Manufacturer:|Family:|Version:|Current Speed:" |grep -E -v "Not Specified|Unknown|^$")
echo "$cpu"

cpu_speed=$(echo "$cpu"|grep -m 1 'Current Speed:' | grep -o [0-9]*)
if [ $cpu_speed -lt $cpu_floor ];then
	echoWarning "Warning: CPU speed is less than $cpu_floor Mhz :("
fi

echoBoldGreen "Memory"
mem_total=$(awk '/MemTotal/{printf "%s", $2}' /proc/meminfo)
mem=$(dmidecode -q -t 17|grep -m 2 -E 'Speed:|Type:')
mem="${mem}"$'\n'$(echo -e "\tInstalled: "$mem_total" KB"; dmidecode -q -t 16|grep -E "Number Of Devices|Maximum Capacity"|sed 's/Number Of Devices/RAM Modules/')
echo "$mem" 

if [ $mem_total -lt $mem_floor ]; then
	echoWarning "Warning: RAM size is less than $mem_floor kB :("
fi

#dmidecode -q -t 17 |grep -E -v  "Array Handle|Error Information Handle|Array Handle|Total Width|Data Width|Set|Asset Tag|Part Number|Handle"

echoBoldGreen "Disk(s)"
parted -l 2>/dev/null > parted.log
disks=$(parted -l 2>/dev/null|grep -v -E '^Disk|^Sector size|Warning:|has been opened read-only|Error:|^$' |sed 's/^/\t/')
if [ -n "$disks" ];then
	echo "$disks"
else
	echoWarning "Warning: There don't seem to be any drives installed in this system! :( \nYou should probably shutdown and check that out."
fi

#TODO Needs to support multiple disks
partitions=$(parted -lm 2>/dev/null)
disk_size=$(echo "$partitions" |awk -F: 'NR==2{printf "%d", $2}')

if [ $disk_size -lt $disk_floor ]; then
	echoWarning "Warning: Disk size is less than $disk_floor GB :("
fi

####################################
# Get disk info
###################################
parted -l 2>/dev/null > ${OUTPUT_DIR}/parted.log


echo "Creating mount dir $MNT_DIR"
mkdir ${MNT_DIR}

echo "Attempting to mount NFS server"
mount -t nfs 10.0.0.1:/var/leseco/results $MNT_DIR

cp -r "$OUTPUT_DIR" $MNT_DIR


####################################
# Stress Test
###################################

stress -c 8 --vm 2 -t 60m >${MNT_DIR}/${OUTPUT_DIR}/stress.log &
stress_dur=720

while [ $stress_dur -gt 1 ]
	do
	((h=stress_dur/360))
	((m=stress_dur%360/60))
	((s=stress_dur%60))
	time_remaining=$(printf "%dh:%dm:%ds\n" $h $m $s)
	echo -ne "\e[01;32mRunning system stress test, time remaining -  ${time_remaining}\e[00m \r"
	sleep 1
	stress_dur=$((stress_dur - 1))
	done

####################################
# Wipe Drive
###################################
nwipe --autonuke --verify=last -m zero -l nwipe.log
cp nwipe.log ${MNT_DIR}/${OUTPUT_DIR}/ 
clear
mount -t nfs 10.0.0.1:/tftpboot/er/shares /home/partimag


####################################
# Clonezilla Restore
###################################

/opt/drbl/sbin/ocs-sr -b -g auto -e1 auto -e2 -c -j2 -k1 -r -p true restoredisk 2012-10-23-02-_Mint-13-Mate-OEM_img sda

