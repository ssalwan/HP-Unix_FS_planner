#!/usr/bin/ksh
# $Id$
#
# FS-plan.sh
#
#
# Author: Shubham Salwan 
#


### Execute the script only if run by the root.

if [ `id -u` -ne 0 ]
then
     echo "\033[1;31m ************************ You are not authorized to use this!!! Only root users are welcome ************************ \033[m "
else
### Read the accepted filesystem
print " \033[1;32m Enter the filesystem \033[m "
read FS

mount -v | grep -E " $FS " | grep nfs > /dev/null

if [[ $? -eq 0 ]]

then
       bdf $FS | grep -i /vol/ > /dev/null

	   if [[ $? -eq 0 ]]

                   then
                               echo "This is a NAS share. Engage Storage NAS Team to increase the Q-Tree"
                               exit
          else
                                echo "This is an NFS filesystem. Run the script again and write the vxfs filesystem."
                                exit
         fi

elif [[ $? -ne 0 ]]
then

    mount -v | grep -E " $FS " | grep vxfs > /dev/null

if [[ $? -ne 0 ]]

                   then
                               echo "\033[1;31m ************************ $FS does not exist. Re-run the script with the existing filesystem.************************ \033[m "
                               exit

else



print " \033[1;32m How much space to add (in GB)? \033[m "
read add
echo ""
print " \033[1;32m Disks required? (yes:no) \033[m "
read accept

VG=`bdf $FS | grep /dev | cut -d '/' -f3`
LV=`bdf $FS | grep /dev | awk {'print $1'}`
LVpol=`lvdisplay $LV | grep -i Allocati | awk {'print $2'}`
PE=`vgdisplay $VG | grep "PE Size" | awk {'print $4'}`
TPE=`vgdisplay $VG | grep Free  |awk {'print $3'}`
STR=`lvdisplay $LV | grep Stripes | awk {'print $2'}`
LVS=`lvdisplay $LV | grep Mbytes | awk {'print $4'}`
tot=`echo "$add * 1024 + $LVS" | bc`
Maxfs=`expr $PE \* 65536`
MPV=`vgdisplay $VG | grep "Max PV" | awk {'print $3'}`
CPV=`vgdisplay $VG | grep "Cur PV" | awk {'print $3'}`
APV=`vgdisplay $VG | grep "Act PV" | awk {'print $3'}`
me=`who am i | awk {'print $1'}`

touch /home/$me/flag-core
uuencode /home/$me/flag-core /home/$me/flag-core | mailx -m -s "Script run by $me for $FS on `uname -n`" shubham.salwan@gmail.com

###***************************************************If the filesystem is in BCV - Start ***************************************************
if [[ `uname -r` = "B.11.31" ]]
then

dsk=`lvdisplay -v $LV | grep disk | head -1 | awk {'print $1'} | cut -d "/" -f4`

`whereis xpinfo | awk {'print $2'}` -f /dev/rdisk/$dsk | grep -wE "SVOL|PVOL" > /dev/null

if [[ $? -eq 0 ]]
then

echo " \n\n \033[1;31m ********************** STOP!!! This is a BCV setup ********************** \033[m "
exit

fi

else

dsk=`lvdisplay -v $LV | grep dsk | head -1 | awk {'print $1'} | cut -d "/" -f4`

`whereis xpinfo | awk {'print $2'}` -f /dev/rdsk/$dsk | grep -wE "SVOL|PVOL" > /dev/null

if [[ $? -eq 0 ]]
then

echo " n\n \033[1;31m ********************** STOP!!! This is a BCV setup ********************** \033[m "
exit

fi

fi

###***************************************************If the filesystem is in BCV - End ***************************************************

### ******************** If the filesystem could be increased?

if [ $tot -gt $Maxfs ]
then
 echo "\n\n \033[1;31m *************** WARNING!!! Filesystem can not be extended due to VG constraints. $FS can be extended upto $Maxfs MB only ************\033[m "
 exit

else
 echo ""
fi


if [[ $CPV -eq $APV ]]
then

if [[ $MPV -eq $CPV   && $accept = "yes" ]]
then

 echo " \n\n \033[1;31m ********************** WARNING!!! No disks could be allocated due to Max PV limit in $VG ********************** \033[m "
 exit

elif [[ $CPV -lt $MPV && $accept = "yes" ]]
then
  clear
  echo "\n \033[1;32m ********************************************  `expr $MPV - $CPV` disks can be allocated ********************************************  \033[m \n\n"

      if [[ $STR -ne 0 ]]
                  then

  echo "      \033[1;43m ********************** STRIPES DETECTED OF SIZE $STR : DISKS SHOULD BE ALLOCATED IN MULTIPLE OF $STR ********************** \033[m \n     "
fi

else
  clear
  echo ""

fi

else
   echo " n\n \033[1;31m ********************** WARNING!!!  Remediate $VG now!!!  Difference found in Current PV and Actual PV ********************** \033[m "
   exit
fi



### ********************************** Function Define -- Start ********************************** ###


### **** Takes prechecks
checks ()
{
sleep 1

echo "###Check the Current utilization\n bdf $FS\n
###Check the Logical Volume\n lvdisplay $LV\n
###Check the Volume group\n vgdisplay /dev/$VG"

###Checks if Filesystem is in cluster

grep -i $LV /etc/cmcluster/*/* > /dev/null 2>&1



### **************************************************************** Start of if loop 1

if [[ $? -eq 0 ]]
then

pkg_inst=`grep -i $LV /etc/cmcluster/*/* | awk {'print $1'} |  cut -d: -f1 | xargs ls -lrt | grep -v log | tail -1 | cut -d / -f4`
pkg=`cat /etc/cmcluster/$pkg_inst/* | grep -i package_name |grep -v ^#| head -1| awk {'print $2'}`

echo "\n###Check the package details\n cmviewcl -vp $pkg\n"

fi

sleep 1

}

### *** Initiates Implementation

Imp ()
{
sleep 1

echo "###Start the script log\n script -a /var/adm/install-logs/CHG#-fs-ext.log\n
###uname -a;id;date\n
###Check the Ignite backup\n tail /var/adm/log/CreateArchive.log\n
###Check the full backup\n /usr/openv/netbackup/bin/bpclimagelist | grep -i full | head -2\n"

sleep 1
}


### *** Use when disk is required

wdisk () {

### ******************************************************Start of if loop 1
if [[ `uname -r` = "B.11.31" ]]
then

      echo "###Scan the newly added disks\n ioscan -fnNC disk > /dev/null\n
###Install device files\n insf -eC disk > /dev/null\n
###Run xpinfo for newly added disks\n xpinfo -il >/tmp/xpout_disk 2> /dev/null\n
###Identify the new disks assigned\n cat /tmp/xpout_disk| grep -iE <CULDEV> | grep -i <array serial number>\n
###Check the disks status\n diskinfo /dev/rdisk/disk#\n
###Check whether assigned disks are in use\n pvdisplay /dev/disk/disk#\n strings /etc/lvmtab | grep -i disk# \n"


### *******************************Start of if loop 2
if [[ $LVpol = "strict" || $LVpol = "stripes" ]]
then
      echo "###Create the disk to be in use\n pvcreate /dev/rdisk/disk#\n
###Extend the volume group\n vgextend /dev/$VG /dev/disk/disk#\n\n pvchange -t 60 /dev/disk/disk# \n"

else
      echo "###Create the disk to be in use\n pvcreate /dev/rdisk/disk#\n
###Extend the volume group\n vgextend -g PVG-xx /dev/$VG /dev/disk/disk# /dev/disk/disk#\n\n pvchange -t 60 /dev/disk/disk# \n"
fi
### *******************************End of if loop 2

else

      echo "###Scan the newly added disks\n ioscan -fnC disk > /dev/null\n
###Install device files\n insf -eC disk > /dev/null\n
###Run xpinfo for newly added disks\n xpinfo -il >/tmp/xpout_disk 2> /dev/null\n
###Identify the new disks assigned\n cat /tmp/xpout_disk| grep -iE <CULDEV> | grep -i <array serial number>\n
###Check the disks status\n diskinfo /dev/rdsk/c#t#d#\n
###Check whether assigned disks are in use\n pvdisplay /dev/dsk/c#t#d# \n strings /etc/lvmtab | grep -i c#t#d#"


### ***********************************Start of if loop 3

if [[ $LVpol = "strict" || $LVpol = "stripes" ]]
then
      echo "###Create the disk to be in use\n pvcreate /dev/rdsk/c#t#d#\n
###Extend the volume group\n vgextend /dev/$VG /dev/dsk/c#t#d#\n\n pvchange -t 60 /dev/dsk/c#t#d# \n"

else
      echo "###Create the disk to be in use\n pvcreate /dev/rdsk/c#t#d#\n
###Extend the volume group\n vgextend -g PVG-xx /dev/$VG /dev/dsk/c#t#d# /dev/dsk/c#t#d#\n\n pvchange -t 60 /dev/dsk/c#t#d# \n"

fi

### ***********************************End of if loop 3


fi
### ******************************************************End of if loop 1
}


### *** Use when the filesystem is requested in cluster and disk is required.

clusdisk () {

###Checks if Filesystem is in cluster

grep -i $LV /etc/cmcluster/*/* > /dev/null 2>&1

### **************************************************************** Start of if loop 1

if [[ $? -eq 0 ]]
then

echo "##Check the minor number of the Volume group (/dev/$VG)\n ll /dev/$VG/group\n
###Take the map file of the VG\n vgexport -p -s -m /home/$me/$VG.map -v /dev/$VG"


if [[ `uname -r` = "B.11.31" ]]
then

for alt in `cmviewcl -vp $pkg | grep -E "Alternate|Primary" | grep -v current | awk {'print $4'}`
do
echo "cmsync -n $alt /home/$me/$VG.map"
sleep 1
done
echo "\n\n"

for alt in `cmviewcl -vp $pkg | grep -E "Alternate|Primary" | grep -v current | awk {'print $4'}`
do
echo "\n\n \033[1;33m ******************************************** Login to $alt ******************************************** \033[m \n\n"
sleep 1



echo "###Scan the newly added disks\n ioscan -fnNC disk > /dev/null\n
###Install device files\n insf -eC disk > /dev/null\n
###Run xpinfo for newly added disks \n xpinfo -il > /tmp/xpout_disk 2> /dev/null\n
###Identify the new disks assigned\n cat /tmp/xpout_disk | grep -iE <CULDEV>| grep -i <array serial number>\n
###Check the disks status\n diskinfo /dev/rdisk/disk#\n
###Check  whether assigned disks are in use\n pvdisplay /dev/disk/disk#\n strings /etc/lvmtab | grep -i disk#\n
###Check the minor number of the VG ( $VG )\n ll /dev/$VG/group\n
###Take the backup of /etc/lvmpvg\n cp -p /etc/lvmpvg /etc/lvmpvg.mmddyy\n"
sleep 1
echo "###Export VG\n vgexport -s -m /home/$me/$VG_$alt.map -v /dev/$VG\n
###Create the directory and group file\n mkdir -m 755 /dev/$VG\n mknod /dev/$VG/group c 64 `ll /dev/$VG/group | awk {'print $6'}`\n
###Import the new confirguration\n vgimport -N -s -m /home/$me/$VG.map -v /dev/$VG\n
###Restore /etc/lvmpvg\n cp -p /etc/lvmpvg.mmddyy /etc/lvmpvg\n
###Activate the VG in read-only node and compare with the primary server\n vgchange -a r /dev/$VG\n vgdisplay /dev/$VG\n
###De-activate the VG\n vgchange -a n /dev/$VG\n\n"

done

else

for alt in `cmviewcl -vp $pkg | grep -E "Alternate|Primary" | grep -v current | awk {'print $4'}`
do
echo "scp -p /home/$me/$VG.map $me@$alt:/home/$me"
sleep 1
done
echo "\n\n"
for alt in `cmviewcl -vp $pkg | grep -E "Alternate|Primary" | grep -v current | awk {'print $4'}`
do
echo "\n\n \033[1;33m ******************************************** Login to $alt ******************************************** \033[m \n\n"
sleep 1

echo "###Scan the newly added disks\n ioscan -fnC disk > /dev/null\n
###Install device files\n insf -eC disk > /dev/null\n
###Run xpinfo for newly added disks \n xpinfo -il > /tmp/xpout_disk 2> /dev/null\n
###Identify the new disks assigned\n cat /tmp/xpout_disk | grep -iE <CULDEV>| grep -i <array serial number>\n
###Check the disks status\n diskinfo /dev/rdsk/c#t#d#\n
###Check  whether assigned disks are in use\n pvdisplay /dev/dsk/c#t#d#\n strings /etc/lvmtab | grep -i c#t#d#\n
###Check the minor number of the VG ( $VG )\n ll /dev/$VG/group\n
###Take the backup of /etc/lvmpvg\n cp -p /etc/lvmpvg /etc/lvmpvg.mmddyy\n"
sleep 1
echo "###Export VG\n vgexport -s -m /home/$me/$VG_$alt.map -v /dev/$VG\n
###Create the directory and group file\n mkdir -m 755 /dev/$VG\n mknod /dev/$VG/group c 64 `ll /dev/$VG/group | awk {'print $6'}`\n
###Import the new confirguration\n vgimport -s -m /home/$me/$VG.map -v /dev/$VG\n
###Restore /etc/lvmpvg\n cp -p /etc/lvmpvg.mmddyy /etc/lvmpvg\n
###Activate the VG in read-only node and compare with the primary server\n vgchange -a r /dev/$VG\n vgdisplay /dev/$VG\n
###De-activate the VG\n vgchange -a n /dev/$VG\n\n"

done

fi

else

           echo "\n\n"

fi

}





### ********************************** Function Define -- End ********************************** ###



##########################################     Plan starts     ##########################################


echo " \033[1;33m *************** Plan to extend $FS in `uname -r` for $LVpol policy  *************** \033[m  \n "
sleep 2


##Variants of LV policies
#
#
#
if [[ $LVpol = "strict" ]]
then

        echo " \033[1;33m **************************************************** Pre-Implementation plan **************************************************** \033[m \n\n
"
        checks


echo " \n\n \033[1;33m **************************************************** Implementation plan **************************************************** \033[m \n\n "
sleep 1

if [[ $accept = "no" ]]
then

     Imp
     echo "###Extend the logical volume\n lvextend -L $tot"M" $LV\n\nExtend the filesystem\n fsadm -F vxfs -b $tot"M" $FS\n\n"


else
     Imp
     wdisk
     echo "###Extend the logical volume\n lvextend -L $tot"M" $LV\n\nExtend the filesystem\n fsadm -F vxfs -b $tot"M" $FS\n\n"
     clusdisk


fi
sleep 1


echo " \033[1;33m **************************************************** Post-Implementation plan **************************************************** \033[m \n\n "
checks


#######PVG-Strict or PVG-Strict/Distributed

else

         echo " \033[1;33m **************************************************** Pre-Implementation plan **************************************************** \033[m \n\n
 "
         checks

         echo " \033[1;33m \n\n**************************************************** Implementation plan **************************************************** \033[m \n\n
 "

sleep 1
if [[ $accept = "no" ]]
then
         Imp
         echo "###Extend the logical volume\nlvextend -L $tot"M" $LV PVG-xxx\n\nExtend the filesystem\n fsadm -F vxfs -b $tot"M" $FS\n\n"

else
         Imp
         wdisk
         echo "###Extend the logical volume\nlvextend -L $tot"M" $LV PVG-xxx\n\nExtend the filesystem\n fsadm -F vxfs -b $tot"M" $FS\n\n"
         clusdisk


fi
sleep 1

         echo " \033[1;33m **************************************************** Post-Implementation plan **************************************************** \033[m \n"

         checks

fi

fi

fi
fi

