#!/bin/bash

#================================================================================================
##
##		Unassigned Devices Share Re-Mounter - Espressomatic @UnraidForums - 15 Sep 2024
##											- inspired by script from Marc Gutt @UnraidForums - 20 Nov 2020
##		version 1.0
##
##		Keep Unassigned Devices' "Automount" remote shares mounted
##
##================================================================================================
#
#	Info
#	----
#
#	Tested on Unraid versions 6.12 and 7.0 betas
#
#	Remote shares set up in Unassigned Devices as Automount are only brought online when the system
#	is first started. If the shares become unmounted for any reason, such as rebooting their
#	server(s), they remain unavailble, potentially causing problems for apps/containers where
#	they're referenced, such as Plex/Jellyfin, etc.
#
#	This script checks which shares are currently unmounted, verifies the server is available,
#	then uses Unassigned Devices own mount function to reactivate them.
#
#	When scheduled as instructed below, the script will run every 5 minutues.
#
#
#	Required Installation and Setup
#	-------------------------------
#
#	- Install "User Scripts" plugin on each Unraid Server that will run this script
#
#	- Create a new script named "Re-Mount Unassigned Devices Remote Shares"
#
#	- Click script options, click Edit Description, select the "No description" text and replace with
#		"Mount unmounted shares if they're set to Automount" - click the green check-mark icon
#
#	- Click script options (gear icon), click Edit Script and Copy and Paste this script
#		into the editor - Click the Save Changes button
#
#	- There is no need to edit nor make changes to the script
#
#	- Click the Run Script button to test - shares are checked and mounted as needed
#
#	- Click the Schedule button for the script and select a custom schedule
#
#	- Paste "*/5 * * * *" into the text box to the right, excluding quotes
#
#	- Click the Apply button at the bottom
#
##================================================================================================


##================================================================================================
##------------------------------------------------------------------------------------------------
## The Business	- you shouldn't need to make edits below for typical use
##------------------------------------------------------------------------------------------------
##================================================================================================

## Make script race condition safe
#
if [[ -d "/tmp/${0///}" ]] || ! mkdir "/tmp/${0///}"; then exit 1; fi; trap 'rmdir "/tmp/${0///}"' EXIT;

## Read Unassigned Devices mount list for remote shares (/tmp/unassigned.devices/config/samba_mount.cfg)
#
printf "\n\nStarting...\n\n"

cat "/tmp/unassigned.devices/config/samba_mount.cfg" | while read line
do

	# Process a server entry when found ( lines starting with "[" )
	#
	if [[ "$line" == [* ]];then

		check_server=$line
		read line			# move to the next line - share protocol

		# Get the share type - SMB or NFS (needed later for differences in mounting)
		#
		if [[ $line == "protocol"* ]]; then
			share_type=$(cut -d'"' -f\2 <<<"$line")
			if [[ $share_type != "SMB" ]] && [[ $share_type != "NFS" ]]; then
				printf "Not NFS or SMB ... skipping\n\n"
				continue
			fi
		fi

		# Check Unassigned Devices Automount setting for each share
		#
		while read line
		do
			if [[ $line == "automount"* ]]; then
				break
			fi
		done

		# If this is an Automount share, check its type and whether it needs to be re-mounted
		#
		if [[ $line == "automount"*"yes"* ]]; then
			
			if [[ $share_type == "SMB" ]]; then
				#---------------------------------------------------------------------------------------------
				# SMB | Mount the share if it's not currently mounted & the server is online
				#
				# [//SERVER/sharename]

				server_name=${check_server##*//}
				server_name=${server_name%/*}

				share_name=${check_server##*/}
				share_name=${share_name%%]*}

				mount_name="${server_name}_${share_name}"

				if mount -t cifs | grep -q "$mount_name"; then
					printf "SMB share $mount_name is already mounted\n\n"
				
					check_server=""
				else
					ping -c 1 -W 1 $server_name > /dev/null 2>&1
					if [[ $? -eq 0 ]]; then
						printf "Mounting SMB share //${server_name}/${share_name} as ${mount_name} ... "
						/usr/bin/nice /var/local/overlay/usr/local/sbin/rc.unassigned mount "//${server_name}/${share_name}"
						printf "\n"
					fi
				fi
				#---------------------------------------------------------------------------------------------
			else
				#---------------------------------------------------------------------------------------------
				# NFS | Mount the share if it's not currently mounted & the server is online
				#
				# [SERVER:/mnt/some_pool/sharename]
				
				server_name=${check_server##*[}
				server_name=${server_name%%:*}

				share_path=${check_server#*:}
				share_path=${share_path%]*}

				share_name=${check_server##*/} 
				share_name=${share_name%%]*}

				mount_name="${server_name}_${share_name}"

				if mount -t nfs4 | grep -q "$mount_name"; then
					printf "NFS share $mount_name is already mounted\n\n"
					check_server=""
				else
					ping -c 1 -W 1 $server_name > /dev/null 2>&1
					if [[ $? -eq 0 ]]; then
						printf "Mounting NFS share ${server_name}:${share_path} as ${mount_name} ... "
						/usr/bin/nice /var/local/overlay/usr/local/sbin/rc.unassigned mount "${server_name}:${share_path}"
						printf "\n"
					fi
				fi
				#---------------------------------------------------------------------------------------------
			
			fi
		fi
	fi
done

printf "\n...Finished\n\n"

##================================================================================================
