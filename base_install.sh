#!/bin/bash 

set -e

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
CONFIG_FILE=$SCRIPT_DIR/install.conf
DEFAULT_APP=$SCRIPT_DIR/default_app.txt
source $CONFIG_FILE


logo (){
clear
echo -ne "
-------------------------------------------------------------------------
				
				installing Arch Linux
				
-------------------------------------------------------------------------
				     $1
-------------------------------------------------------------------------
"
}


check_conf (){
	logo CHECK_CONF
	if [ ! -f $CONFIG_FILE ]
	then # check if file exists
    		bash $SCRIPT_DIR/conf_install.sh  # run conf_install file
    	elif [ -f $CONFIG_FILE ]
    	then
    		if [[ ! -z $DISK && $ROOT && $BOOT_TYPE && $USERNAME && $PASSWORD && $Rootpasswd && $TIMEZONE ]]
    		then
    			echo "     done."
    			sleep 2
    		elif [[ -z $DISK || $ROOT || $BOOT_TYPE || $USERNAME || $PASSWORD || $Rootpasswd || $TIMEZONE ]]
    		then
    			bash $SCRIPT_DIR/conf_install.sh  # run conf_install file
    		fi
	fi
}

setting (){
	iso=$(curl -4 ifconfig.co/country-iso)
	timedatectl set-ntp true
	sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
	pacman -S --noconfirm reflector rsync grub
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -ne "
-------------------------------------------------------------------------
                    Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------
"
	reflector -a 48 -c $iso -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
	mkdir /mnt &>/dev/null # Hiding error message if any
}


Boot_partiton (){
echo -ne "
-------------------------------------------------------------------------
                    Formating Disk
-------------------------------------------------------------------------
"
	if [ ! -z $BOOT ]; then

		if [ $(echo "$BOOT_TYPE" |tr [:upper:] [:lower:]) = "uefi" ]; then
			mkfs.fat -n ESP -F32 $BOOT
		fi

		if [ $(echo "$BOOT_TYPE" |tr [:upper:] [:lower:]) = "bios" ]; then
			mkfs.ext4 -L boot $BOOT
		fi
	fi
}


Make_partitons (){
	mkfs.ext4 $ROOT
	mkswap $SWAP
}


Home_partiton (){
	if [ ! -z $HOME ];then
	makdir /mnt/home
	mkfs.ext4 $HOME
	mount $HOME /mnt/home
	fi

}

Mount (){
	cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
	mount $ROOT /mnt
	swapon $SWAP
	Home_partiton
}


Base (){
echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
	pacstrap /mnt base base-devel linux linux-firmware vim nano sudo archlinux-keyring wget libnewt --noconfirm --needed
	cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

}

install_grub (){
	if [ $(echo "$BOOT_TYPE" | tr [:upper:] [:lower:]) = "bios" ]; then

			arch-chroot /mnt pacman -Syu --noconfirm --needed  grub

			arch-chroot /mnt grub-install --target=i386-pc $DISK

			arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
		fi
		if [ $(echo "$BOOT_TYPE" | tr [:upper:] [:lower:]) = "uefi" ]; then

			arch-chroot /mnt pacman -Syu --noconfirm --needed grub efibootmgr
			arch-chroot /mnt  mkdir /boot/efi
			arch-chroot /mnt  mount $BOOT /boot/efi
			arch-chroot /mnt  grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
			arch-chroot /mnt  grub-mkconfig -o /boot/grub/grub.cfg


		fi

}

conf_system (){
echo -ne "
-------------------------------------------------------------------------
                    Configer your System
-------------------------------------------------------------------------
"
	genfstab -U /mnt >> /mnt/etc/fstab
	#arch-chroot /mnt timedatectl set-timezone $TIMEZONE
	arch-chroot /mnt sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
	arch-chroot /mnt  locale-gen
	arch-chroot /mnt touch /etc/locale.conf
	arch-chroot /mnt  echo LANG=en_US.UTF-8 > /etc/locale.conf
	arch-chroot /mnt touch /etc/hostname
	arch-chroot /mnt  echo "arch" > /etc/hostname
	arch-chroot /mnt touch /etc/hosts
	arch-chroot /mnt  echo -e "127.0.0.1	localhost\n::1	localhost\n127.0.1.1	arch.localdomain	arch" >> /etc/hosts
	#arch-chroot /mnt ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
	#arch-chroot /mnt localectl --no-ask-password set-keymap ${KEYMAP}
	sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers

}


default_app (){
echo -ne "
-------------------------------------------------------------------------
                    Install Default APP
-------------------------------------------------------------------------
"
	cat $DEFAULT_APP | while read line 
	do
    		echo "INSTALLING: ${line}"
   		arch-chroot /mnt pacman -Syu --noconfirm --needed ${line}
	done
	arch-chroot /mnt systemctl enable NetworkManager
}


micorcode (){
echo -ne "
-------------------------------------------------------------------------
                    Installing Microcode
-------------------------------------------------------------------------
"
	# determine processor type and install microcode
	proc_type=$(lscpu)
	if grep -E "GenuineIntel" <<< ${proc_type}; then
    		echo "Installing Intel microcode"
    		arch-chroot /mnt pacman -Syu --noconfirm intel-ucode
    		proc_ucode=intel-ucode.img
	elif grep -E "AuthenticAMD" <<< ${proc_type}; then
    		echo "Installing AMD microcode"
    		arch-chroot /mnt pacman -Syu --noconfirm amd-ucode
    		proc_ucode=amd-ucode.img
    	else
    		echo "Your CPU Not Supported"
    		sleep 2
	fi

}


graphics_driver (){
echo -ne "
-------------------------------------------------------------------------
                    Installing Graphics Drivers
-------------------------------------------------------------------------
"
# Graphics Drivers find and install
gpu_type=$(lspci)
if grep -E "NVIDIA|GeForce" <<< ${gpu_type}; then
    arch-chroot /mnt pacman -Syu nvidia --noconfirm --needed
	nvidia-xconfig
elif lspci | grep 'VGA' | grep -E "Radeon|AMD"; then
    arch-chroot /mnt pacman -Syu xf86-video-amdgpu --noconfirm --needed
elif grep -E "Integrated Graphics Controller" <<< ${gpu_type}; then
    arch-chroot /mnt pacman -Syu libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa --needed --noconfirm
elif grep -E "Intel Corporation UHD" <<< ${gpu_type}; then
    arch-chroot /mnt pacman -Syu libva-intel-driver libvdpau-va-gl lib32-vulkan-intel vulkan-intel libva-intel-driver libva-utils lib32-mesa --needed --noconfirm
else
	echo "Your Graphics Drive Not Supported"
	sleep 2
fi

}


add_user () {
	echo -ne "
-------------------------------------------------------------------------
                    Adding User
-------------------------------------------------------------------------
"
	arch-chroot /mnt echo "root:$Rootpasswd" | chpasswd
	arch-chroot /mnt useradd -m -G wheel,storage,optical,audio,video,root -s /bin/bash $USERNAME
	arch-chroot /mnt echo "$USERNAME:$PASSWORD" | chpasswd
}




Main (){
	check_conf
	setting
	Boot_partiton
	Make_partitons
	Home_partiton
	Mount
	Base
	install_grub
	conf_system
	default_app
	micorcode
	graphics_driver
	add_user
echo -ne "
-------------------------------------------------------------------------
                    Install Arch Successfully
-------------------------------------------------------------------------
"
}
Main
