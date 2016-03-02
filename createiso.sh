#!/bin/bash
#set -x # debug flag
###############################################################################
# HARDENED RHEL DVD CREATOR
#
# This script was written by Frank Caviggia, Red Hat Consulting
# Last update was 21 July 2015
# This script is NOT SUPPORTED by Red Hat Global Support Services.
# Please contact Josh Waldman for more information.
#
# Author: Frank Caviggia (fcaviggi@redhat.com)
# Copyright: Red Hat, (c) 2014
# Version: 1.2.5
# License: GPLv2
# Description: Kickstart Installation of RHEL 6 with DISA STIG 
###############################################################################

# GLOBAL VARIABLES
DIR=`pwd`

# USAGE STATEMENT
function usage() {
cat << EOF
usage: $0 rhel-server-6.5-x86_64-dvd.iso

Hardened RHEL/CENTOS Kickstart for version 6.4+

Customizes a RHEL/CENTOS 6.4+ x86_64 DVD to install
with the following hardening:

  - DISA STIG/USGCB/NSA SNAC for Red Hat Enterprise Linux
  - DISA STIG for Firefox (User/Developer Workstation)
  - Classification Banner (Graphical Desktop)

EOF
}

while getopts ":vhq" OPTION; do
	case $OPTION in
		h)
			usage
			exit 0
			;;
		?)
			echo "ERROR: Invalid Option Provided!"
			echo
			usage
			exit 1
			;;
	esac
done

# Check for root user
if [[ $EUID -ne 0 ]]; then
	if [ -z "$QUIET" ]; then
		echo
		tput setaf 1;echo -e "\033[1mPlease re-run this script as root!\033[0m";tput sgr0
	fi
	exit 1
fi

# Check for required packages
rpm -q genisoimage &> /dev/null
if [ $? -ne 0 ]; then
	yum install -y genisoimage
fi

rpm -q isomd5sum &> /dev/null
if [ $? -ne 0 ]; then
	yum install -y isomd5sum
fi

# Determine if DVD is Bootable
`file $1 | grep 9660 | grep -q bootable`
if [[ $? -eq 0 ]]; then
	echo "Mounting DISTRO DVD Image..."
	mkdir -p /distro
	mkdir $DIR/distro-dvd
	mount -o loop $1 /distro
	echo "Done."

    # Support RHEL & CentOS
    if [[ -e /distro/.discinfo ]]; then
        # check to see if centos or rhel

        RHEL_VERSION=$(grep "Red Hat" /distro/.discinfo | awk '{ print $5 }')
        CENTOS_VERSION=$(grep "^[0-9]\{1\}\.[0-9]\{1\}$" /distro/.discinfo)

        # if rhel contains version number
        if [[ -n "$RHEL_VERSION" ]]; then
            DISTRO="rhel"
        elif [[ -n "$CENTOS_VERSION" ]]; then
            DISTRO="centos"
        else
		    echo "ERROR: Image is not RHEL....exiting"
		    exit 1
        fi
        
        if [[ "$DISTRO" -eq "centos" ]]; then
            DISTRO_VERSION=$CENTOS_VERSION
        elif [[ "$DISTRO" -eq "rhel" ]]; then
            DISTRO_VERSION=$RHEL_VERSION
        else
            echo "ERROR: Distro name not being set properly....exiting"
            exit 1
        fi

        # verify proper version number
        MAJOR_VERSION=$(echo $DISTRO_VERSION | awk -F '.' '{ print $1 }')
        MINOR_VERSION=$(echo $DISTRO_VERSION | awk -F '.' '{ print $2 }')

        # verify that we are using a "6" version
        if [[ $MAJOR_VERSION -ne 6 ]]; then
			echo "ERROR: Image is not RHEL 6.4+"
			umount /distro
			rm -rf /distro
			exit 1
        fi

        # verify that we are using a "4+" version
		if [[ $MINOR_VERSION -lt 4 ]]; then
			echo "ERROR: Image is not RHEL 6.4+"
			umount /distro
			rm -rf /distro
			exit 1
		fi

	    echo -n "Copying DISTRO DVD Image..."
	    cp -a /distro/* $DIR/distro-dvd/
	    cp -a /distro/.discinfo $DIR/distro-dvd/
	    echo " Done."
	    umount /distro
	    rm -rf /distro

        echo -n "Modifying DISTRO DVD Image..."
        sed -i "s/6.X/$DISTRO_VERSION/g" $DIR/config/isolinux/isolinux.cfg
        sed -i "s/DISTRO NAME/$DISTRO_NAME/g" $DIR/config/isolinux/isolinux.cfg
        cp -a $DIR/config/* $DIR/distro-dvd/
        sed -i "s/$DISTRO_VERSION/6.X/g" $DIR/config/isolinux/isolinux.cfg
        sed -i "s/$DISTRO_NAME/DISTRO NAME/g" $DIR/config/isolinux/isolinux.cfg
        echo " Done."

        echo "Remastering DISTRO DVD Image..."
        cd $DIR/distro-dvd
        chmod u+w isolinux/isolinux.bin
        find . -name TRANS.TBL -exec rm '{}' \; 
        /usr/bin/mkisofs -J -T -o $DIR/ssg-$DISTRO-$DISTRO_VERSION.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -m TRANS.TBL .
        cd $DIR
        rm -rf $DIR/distro-dvd
        echo "Done."

        # cleanup
        rm config/isolinux/sed*

        # signing dvd
        echo "Signing $DISTRO DVD Image..."
        /usr/bin/implantisomd5 $DIR/ssg-$DISTRO-$DISTRO_VERSION.iso
        echo "Done."

        echo "DVD Created. [ssg-$DISTRO-$DISTRO_VERSION.iso]"

    fi

else
	echo "ERROR: ISO image is not bootable."
	exit 1
fi

exit 0
