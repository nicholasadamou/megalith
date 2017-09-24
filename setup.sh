#!/bin/bash
# Based on Raspberry Pi seedbox with Transmission and TorGuard
# see: https://www.convalesco.org/articles/2015/06/08/raspberry-pi-seedbox-with-transmission-and-torguard.html

app_name="Megalith"
moniker="4d4m0u"
link="http://github.com/nicholasadamou/$app_name"

user=pi
rpcPort=0
drive=/mnt/data

root_check() {
	if (( $EUID != 0 )); then
		echo "This must be run as root. Try 'sudo bash $0'."
		exit 1
	fi
}

init() {
	echo "$(tput setaf 6)This script will configure your Raspberry Pi as a torrentbox.$(tput sgr0)"
	read -r -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"
}

update_pkgs() {
	echo "$(tput setaf 6)Updating packages...$(tput sgr0)"
	apt-get update -q -y
}

install_pkgs() {
	pkgs=("transmission-daemon" "exfat-fuse" "ntfs-3g" "avahi-daemon" "jq")

	for i in ${pkgs[*]}
	do
		echo "$(tput setaf 6)Installing [$(tput setaf 6)$i$(tput setaf 6)]...$(tput sgr0)"
		apt-get install "$i"
	done
}

configure_usb() {
	echo "$(tput setaf 6)Please insert Mass Storage Device into USB Slot.$(tput sgr0)"
	read -r -p "$(tput bold ; tput setaf 2)Press [Enter] after inserting Mass Storage Device...$(tput sgr0)"
	sleep 10

	#see: http://stackoverflow.com/questions/42750692/how-do-i-grab-a-specific-section-of-a-stdout
	disk="/dev/"$(tail /var/log/messages | grep -Po 'sd[a-z]+: \Ksd[a-z0-9]+$')

	if [ "$disk" ] ; then
		echo "$(tput setaf 6)Mass Storage Device [$(tput setaf 5)$disk$(tput setaf 6)] detected.$(tput sgr0)"

		partion_type=$(sudo blkid "$disk" -s TYPE -o value)

		#format usb drive as 'ext4' if not already 'ext4'
		if [ "$partion_type" != "ext4" ] ; then
			read -r -p "$(tput setaf 6)Do you want to format $disk as ext4? [y/N] $(tput sgr0)" choice
			if [ "$choice" == "y" ] || [ "$choice" == "Y" ] ; then
				echo "$(tput setaf 6)Formatting Mass Storage Device [$(tput setaf 5)$disk$(tput setaf 6)] as ext4...$(tput sgr0)"
				mkfs.ext4 "$disk"
			elif [ "$choice" == "n" ] || [ "$choice" == "N" ] ; then
				closing
				exit 0
			fi
		fi

		target="$drive"

		if ! [ -d "$target" ] ; then
			mkdir -p "$target"
		fi

		mount "$disk" "$target"

		if ! [ -d "$target"/{downloads,incomplete} ] ; then
			mkdir "$target"/{downloads,incomplete}
		fi

		chown "$user":users "$target"/{downloads,incomplete}

		#mount it automatically on reboot
		#see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/
		x=/etc/fstab
		cp "$x" "$x".bak
		echo "" >> "$x"
		echo "#disk used for $app_name" >> "$x"
		echo "#see: $link" >> "$x"
		echo "#see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/" >> "$x"
		echo "$disk" "$target" "$partion_type" defaults 0 2 >> "$x"
	fi
}

configure_transmission() {
	echo "$(tput setaf 6)Configuring transmission...$(tput sgr0)"
	read -r -p "$(tput setaf 6)Specify \"RPC username\": $(tput sgr0)" -e username
	read -r -p "$(tput setaf 6)Specify \"RPC Passphrase\": $(tput sgr0)" -e passwd
	read -r -p "$(tput setaf 6)Specify \"RPC Port\": $(tput sgr0)" -e port
	read -r -p "$(tput setaf 6)Specify \"RPC whitelist\": $(tput sgr0)" -e whitelist

	rpcPort=$port

	downloads="$drive"/downloads
	incomplete="$drive"/incomplete

	#stop the transmission for configuring
	/etc/init.d/transmission-daemon stop

	x=/etc/transmission-daemon/settings.json
	cp "$x" "$x".bak
	jq_replace "$x" rpc-username "$username"
	jq_replace "$x" rpc-password "$passwd"
	jq_replace "$x" rpc-port "$port"
	jq_replace "$x" download-dir "$downloads"
	jq_replace "$x" incomplete-dir "$incomplete"
	jq_replace "$x" incomplete-dir-enabled true
	jq_replace "$x" watch-dir "$drive"
	jq_replace "$x" watch-dir-enabled true
	jq_replace "$x" rpc-whitelist "$whitelist"
	jq_replace "$x" rpc-authentication-required false
	jq_replace "$x" umask 2

	x=/etc/init.d/transmission-daemon
	cp "$x" "$x".bak
	replace_str "$x" USER debian-transmission "$user"

	x=/etc/systemd/system/multi-user.target.wants/transmission-daemon.service
	cp "$x" "$x".bak
	replace_str "$x" User debian-transmission "$user"

	#reload transmission to apply configurations
	service transmission-daemon reload

	mkdir -p /home/"$USER"/.config/transmission-daemon/
	ln -s /etc/transmission-daemon/settings.json /home/"$USER"/.config/transmission-daemon/settings.json
	chown -R "$user":users /home/"$USER"/.config/transmission-daemon/

	#restart transmission
	service transmission-daemon restart
}

#setting up Samba Server
#see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/
configure_samba() {
	echo "$(tput setaf 6)Installing samba...$(tput sgr0)"
	apt-get remove wolfram-engine
	apt-get install samba samba-common-bin

	echo "$(tput setaf 6)Configuring samba...$(tput sgr0)"

	x=/etc/samba/smb.conf
	cp "$x" "$x".bak

	name=app_name
	comment="Always-On Downloading $name"

	cat < "$x" <<- EOL
	["$name"]
	comment = "$comment"
	path = "$drive"
	valid users = @users
	force group = users
	create mask = 0775
	force create mode = 0775
	security mask = 0775
	force security mode = 0775
	directory mask = 2775
	force directory mode = 2775
	directory security mask = 2775
	force directory security mode = 2775
	browseable = yes
	writeable = yes
	guest ok = no
	read only = no
	EOL

	sed -i -e 's/#security = user;/security = user;/g' "$x"

	#restart samba
	service samba restart

	#configure samba user
	smbpasswd -a "$user"
	chown "$user":users "$drive"
	chmod g+w "$drive"
}

enable_on_boot() {
	echo "$(tput setaf 6)Setting transmission to start on system boot...$(tput sgr0)"
	update-rc.d transmission-daemon enable
}

finish() {
	ip=$(ifconfig wlan0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)
	echo "$(tput setaf 6)Setup complete!

		$(tput bold)Connect to: $(tput setaf 3)http://$ip:$rpcPort $(tput setaf 6)and login to the Transmission WebUI.$(tput sgr0)
	  "
		closing
}

closing() {
	echo "$(tput setaf 6)Thanks for using $(tput bold ; tput setaf 5)$app_name$(tput sgr0)$(tput setaf 6) by $(tput bold ; tput setaf 5)$moniker$(tput sgr0)$(tput setaf 6)!$(tput sgr0)"
}

replace_str() {
	x=$1
	sed -i -e "/$2/ s/$3/$4/g" "$x"
}

jq_replace() {
	x="$1"
	field="$2"
	value="$3"

	if [ "$(which jq)" ] ; then
		jq ".\"$field\" |= \"$value\"" "$x" > tmp.$$.json && mv tmp.$$.json "$x"
	else
		apt-get install jq

		jq ".\"$field\" |= \"$value\"" "$x" > tmp.$$.json && mv tmp.$$.json "$x"
	fi
}

begin() {
	root_check
	init
	update_pkgs
	install_pkgs
	configure_usb
	configure_transmission
	configure_samba
	enable_on_boot
	finish
}

begin
