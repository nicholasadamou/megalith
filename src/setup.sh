#!/bin/bash

# Based on Raspberry Pi seedbox with Transmission and TorGuard
# see: https://www.convalesco.org/articles/2015/06/08/raspberry-pi-seedbox-with-transmission-and-torguard.html

declare BASH_UTILS_URL="https://raw.githubusercontent.com/nicholasadamou/utilities/master/utilities.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

declare APP_NAME="Megalith"
declare link="https://github.com/nicholasadamou/$APP_NAME"

declare user=pi
declare rpcPort=0
declare drive=/mnt/data

setup_megalith() {
    echo "$(tput setaf 6)This script will configure your Raspberry Pi as a torrentbox.$(tput sgr0)"

    read -r -p "$(tput bold ; tput setaf 2)Press [Enter] to begin, [Ctrl-C] to abort...$(tput sgr0)"

	apt_update
	apt_upgrade

	apt remove -qqy wolfram-engine

	declare -a PKGS=(
		"transmission-daemon"
		"samba"
		"samba-common-bin"
		"exfat-fuse"
		"ntfs-3g"
		"avahi-daemon"
		"jq"
	)

	for PKG in "${PKGS[@]}"; do
		install_package "$PKG"
	done

	echo "$(tput setaf 6)Please insert Mass Storage Device into USB Slot.$(tput sgr0)"

	read -r -p "$(tput bold ; tput setaf 2)Press [Enter] after inserting Mass Storage Device...$(tput sgr0)"

	sleep 10

	# see: http://stackoverflow.com/questions/42750692/how-do-i-grab-a-specific-section-of-a-stdout
	disk="/dev/"$(tail /var/log/messages | grep -Po 'sd[a-z]+: \Ksd[a-z0-9]+$')

	if [ "$disk" ] ; then
		echo "$(tput setaf 6)Mass Storage Device [$(tput setaf 5)$disk$(tput setaf 6)] detected.$(tput sgr0)"

		partion_type=$(sudo blkid "$disk" -s TYPE -o value)

		# format usb drive as 'ext4' if not already 'ext4'
		if [ "$partion_type" != "ext4" ] ; then
			read -r -p "$(tput setaf 6)Do you want to format $disk as ext4? [y/N] $(tput sgr0)" choice
			if [ "$choice" == "y" ] || [ "$choice" == "Y" ] ; then
				echo "$(tput setaf 6)Formatting Mass Storage Device [$(tput setaf 5)$disk$(tput setaf 6)] as ext4...$(tput sgr0)"
				mkfs.ext4 "$disk"
			elif [ "$choice" == "n" ] || [ "$choice" == "N" ] ; then
				exit 0
			fi
		fi

		target="$drive"

		if ! [ -d "$target" ] ; then
			mkdir -p "$target"
		fi

		sudo mount "$disk" "$target"

		declare -a directories=(
			"downloads"
			"incomplete"
		)

		for directory in "${directories[@]}" ; do
			mkdir -p "$target/$directory"
		done

		sudo chown "$user":users "$target"/{downloads,incomplete}

		# mount it automatically on reboot
		# see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/
		FILE=/etc/fstab
		cp "$FILE" "$FILE".bak
		echo "" >> "$FILE"
		echo "# disk used for $APP_NAME" >> "$FILE"
		echo "# see: $link" >> "$FILE"
		echo "# see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/" >> "$FILE"
		echo "$disk" "$target" "$partion_type" defaults 0 2 >> "$FILE"
	fi

	read -r -p "$(tput setaf 6)Specify \"RPC username\": $(tput sgr0)" -e username
	read -r -p "$(tput setaf 6)Specify \"RPC Passphrase\": $(tput sgr0)" -e passwd
	read -r -p "$(tput setaf 6)Specify \"RPC Port\": $(tput sgr0)" -e port
	read -r -p "$(tput setaf 6)Specify \"RPC whitelist\": $(tput sgr0)" -e whitelist

	rpcPort="$port"

	downloads="$drive"/downloads
	incomplete="$drive"/incomplete

	# stop the transmission for configuring
	/etc/init.d/transmission-daemon stop

	FILE=/etc/transmission-daemon/settings.json
	cp "$FILE" "$FILE".bak
	jq_replace "$FILE" rpc-username "$username"
	jq_replace "$FILE" rpc-password "$passwd"
	jq_replace "$FILE" rpc-port "$port"
	jq_replace "$FILE" download-dir "$downloads"
	jq_replace "$FILE" incomplete-dir "$incomplete"
	jq_replace "$FILE" incomplete-dir-enabled true
	jq_replace "$FILE" watch-dir "$drive"
	jq_replace "$FILE" watch-dir-enabled true
	jq_replace "$FILE" rpc-whitelist "$whitelist"
	jq_replace "$FILE" rpc-authentication-required false
	jq_replace "$FILE" umask 2

	FILE=/etc/init.d/transmission-daemon
	cp "$FILE" "$FILE".bak
	replace_str "$FILE" USER debian-transmission "$user"

	FILE=/etc/systemd/system/multi-user.target.wants/transmission-daemon.service
	cp "$FILE" "$FILE".bak
	replace_str "$FILE" User debian-transmission "$user"

	# reload transmission to apply configurations
	sudo service transmission-daemon reload

	mkdir -p /home/"$USER"/.config/transmission-daemon/
	sudo ln -s /etc/transmission-daemon/settings.json /home/"$USER"/.config/transmission-daemon/settings.json
	sudo chown -R "$user":users /home/"$USER"/.config/transmission-daemon/

	# restart transmission
	service transmission-daemon restart

	# setting up Samba Server
	# see: http://www.makeuseof.com/tag/how-to-turn-your-raspberry-pi-into-an-always-on-downloading-megalith/
	FILE=/etc/samba/smb.conf
	cp "$FILE" "$FILE".bak

	name="$APP_NAME"
	comment="Always-On Downloading $name"

	sudo bash -c "cat > $FILE" <<-EOL
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

	sudo sed -i -e 's/#security = user;/security = user;/g' "$FILE"

	# restart samba
	service samba restart

	# configure samba user
	smbpasswd -a "$user"
	sudo chown "$user":users "$drive"
	sudo chmod g+w "$drive"

	sudo update-rc.d transmission-daemon enable

	ip=$(ifconfig wlan0 | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)

	echo "$(tput setaf 6)Setup complete!

		$(tput bold)Connect to: $(tput setaf 3)http://$ip:$rpcPort $(tput setaf 6)and login to the Transmission WebUI.$(tput sgr0)
	"
}

restart() {
    ask_for_confirmation "Do you want to restart?"

    if answer_is_yes; then
        sudo shutdown -r now &> /dev/null
    fi
}

main() {
    # Ensure that the bash utilities functions have
    # been sourced.

    source <(curl -s "$BASH_UTILS_URL")

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    ask_for_sudo

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    setup_megalith

    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

    restart
}

main
