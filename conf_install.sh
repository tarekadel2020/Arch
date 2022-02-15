#!/bin/bash 

set -e


SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CURRENT=$SCRIPT_DIR/install.sh

CONFIG_FILE=$SCRIPT_DIR/install.conf


conf_file (){
	
	if [ ! -f $CONFIG_FILE ]; then # check if file exists
    		touch -f $CONFIG_FILE # create file if not exists
	fi
}

logo (){
clear
echo -ne "
-------------------------------------------------------------------------
				
				Arch Linux Install
				
-------------------------------------------------------------------------
				    $1
-------------------------------------------------------------------------
"
}

set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then # check if option exists
        sed -i -e "/^${1}.*/d" $CONFIG_FILE # delete option if exists
    fi
    echo "${1}=${2}" >>$CONFIG_FILE # add option
}

timezone () {
# Added this from arch wiki https://wiki.archlinux.org/title/System_time
logo TIMEZONE
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo -ne "System detected your timezone to be '$time_zone' \n"
read -p "Is this correct? yes/no: " answer
case $answer in
    y|Y|yes|Yes|YES)
    set_option TIMEZONE $time_zone;;
    n|N|no|NO|No)
    echo "Please enter your desired timezone e.g. Europe/London :" 
    read new_timezone
    set_option TIMEZONE $new_timezone;;
    *) echo "Wrong option. Try again";timezone;;
esac
}

user-info (){
	logo User-Info
	read -p "Enter User Name :" username
	set_option USERNAME ${username,,}
	read -sp "Enter Password :" password
	set_option PASSWORD $password
	logo ROOT_PASSWORD
	read -sp "Enter Root Password :" rootpasswd
	set_option Rootpasswd $rootpasswd
	#sed -i 's/#user-info/#user-info/' $CURRENT
}

disk (){
	logo Select_Disk
	echo "Select Your Disk"
	select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"("$3")"}' )
	do
	disk=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
	set_option DISK $disk
	break
	done
}

drivessd () {
	logo HARD_TYPE
echo -ne "
Is this an ssd? yes/no:
"
	read ssd_drive

	case $ssd_drive in
    		y|Y|yes|Yes|YES)
    		set_option MOUNTOPTIONS "mountoptions=noatime,compress=zstd,ssd,commit=120";;
    		n|N|no|NO|No)
    		set_option MOUNTOPTIONS  "mountoptions=noatime,compress=zstd,commit=120";;
    		*) echo "Wrong option. Try again";drivessd;;
	esac
}


partitons (){
	logo ROOT_Partitons
	echo "Select Your ROOT"
	select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="part"{print "/dev/"$2"("$3")"}' )
	do
	root=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
	set_option ROOT $root
	break
	done
	logo SWAP_Partitons
	echo "Select Your SWAP"
	select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="part"{print "/dev/"$2"("$3")"}' ) SKIP
	do
	case $i in
	"SKIP")
		set_option SWAP 
		break
	;;
	*)
		swap=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
		set_option SWAP $swap
		break
	;;
	esac
	done
	logo HOME_Partitons
	echo "Select Your HOME"
	select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="part"{print "/dev/"$2"("$3")"}' ) SKIP
	do
	case $i in
	"SKIP")
		set_option HOME 
		break
	;;
	*)
		home=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
		set_option HOME $home
		break
	;;
	esac
	done
	logo BOOT_Partitons
	echo "Select Your BOOT"
	select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="part"{print "/dev/"$2"("$3")"}' ) SKIP
	do
	case $i in
	"SKIP")
		set_option BOOT 
		break
	;;
	*)
		boot=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
		set_option BOOT $boot
		break
	;;
	esac
	done
}

boot_type (){
	logo BOOT_TYPE
	echo "Select Your BOOT TYPE"
	select i in BIOS UEFI
	do
	case $i in
	"BIOS")
		set_option BOOT_TYPE $i
		break
	;;
	"UEFI")
		source $CONFIG_FILE
		if [ -z $BOOT ] 
		then
		logo BOOT_Partitons
		echo "Select Your BOOT"
		select i  in $(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="part"{print "/dev/"$2"("$3")"}' ) SKIP
		do
		case $i in
		"SKIP")
			#set_option BOOT 
			boot_type
			break
			;;
		*)
			boot=$( echo $i|awk '{gsub(/[(]/,";"); print}'|awk  '{sub(/;.*/,""); print}')
			set_option BOOT $boot
			set_option BOOT_TYPE "UEFI"
			break
			;;
		esac
		done
		break
		else
		set_option BOOT_TYPE "UEFI"
		break
		fi
		#set_option BOOT_TYPE $i
	;;
	esac
	done
}

Main(){
	conf_file 
	disk
	drivessd
	partitons 
	boot_type
	user-info
	timezone
	set_option KEYMAP "US"
}

Main
