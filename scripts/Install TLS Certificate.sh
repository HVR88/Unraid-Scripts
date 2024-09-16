#!/bin/bash

##================================================================================================
##
##		Unraid WebUI TLS/SSL Certificate Installer - Espressomatic @UnraidForums - 7 Sep 2024
##
##		version 1.5
##
##		Copy certs from "X Proxy Manager" (or elsewhere) to Unraid Certificate Bundle
##
##================================================================================================
#
#	Info
#	----
#
#	Tested on Unraid versions 6.12 and 7.00
#
#	This script makes the assumption that the source is a certificate chain of 4 files
#	These 4 files will be concatenated together to make a certificate bundle for Unraid
#
#	If you don't use NPM, you may supply a custom path below as a source for the certificate file(s)
#
#	If the source isn't a certificate chain of 4 files named as expected, you'll need to edit
#	the "NPM filenames" variables below the "Business" section 
#	- contact me and I'll try to update the script to support these alternatives
#
#
#	Required Installation and Setup
#	-------------------------------
#
#	- Install NPM (Official) Docker app and set it up to generate a certificate for your server with Let's Encrypt
#
#	- Install "User Scripts" plugin on each Unraid Server that will run this script
#
#	- Create a new script named "Unraid SSL/TLS Certificate Installer"
#
#	- Click script options, click Edit Description, select the "No description" text and replace with
#		"Copy TLS Certificate from X into Unraid" - click the green check-mark icon
#
#	- Click script options (gear icon), click Edit Script and Copy and Paste this script
#		into the editor - Click the Save Changes button
#
#	- Edit the REQUIRED SETTINGS below in the User Scripts Editor and then click the Save Changes button
#
#	 * If your certificates are generated on a different/remote Unraid system, you need to have that system's
#		appdata directory mounted on this system using Unassigned Devices AND the directory where
#		the certs are stored needs to have READ permissions set for all
#
#	- Click the Run Script button for this script - your certificate should be installed
#
#	- Click the Schedule button for the script and select a weekly schedule
#		NPM renews certificates a 4 weeks before they expire and this makes sure the installed copy
#		is always up-to-date and valid
#
#	- Click the Apply button at the bottom
#
##================================================================================================


##------------------------------------------------------------------------------------------------
##	REQUIRED SETTINGS
##------------------------------------------------------------------------------------------------


##  Edit the following FOUR variables for your specific server (where this script is installed)
##  ------------------------------------------------------------------------------------------

## (1)	The name (without domain) of this Unraid server (where you're installing this script)
#	- this must match what's in the subdomain portion of the FQDN in the certificate file
#	- the certificate should have been generated in the format servername.domain.tld
#
this_server_name=""


## (2)	The name (without domain) of the Unraid server where certificates are stored - leave blank if same as above
#	REQUIREMENT: you must have the appdata directory of the remote server mounted on this server 
#				 using Unassigned Devices in the default mount path - example: /mnt/remotes/REMOTESERVER_appdata
#
cert_server_name=""


## (3)	The Proxy App's appdata directory
#	- The name of the appdata directory for the docker app you've installed - case sensitive (example: "Nginx-Proxy-Manager-Official" )
#
app_dir="nginx_proxy"


# TODO: Change this to find the folder based on the server name
## (4)	Certificate-specific source directory
#	- inside NPMPlus appdata hierarchy, certs are created in numerical order
#
cert_dir="npm-#"


## To Do - Later
## (0)	Certificate Source Platform - NPM, pfSense, Traefik, etc.
#	- what platform is used to generate and store the original certificates?
#
#cert_platform="npm"

# how to copy certs from pfsense 
# https://victorlclopes.medium.com/copy-pfsense-acme-certificate-to-another-server-e42c611c47ec
#

##------------------------------------------------------------------------------------------------
## CUSTOM CERTIFICATE SOURCE OVERRIDE (not using a supported platform above)
##------------------------------------------------------------------------------------------------

## Custom Path for the original certificate chain pem files - overrides default NPM-based paths
#  Uncomment and set to your custom path as needed - script edits required if chain files different
#
#custom_cert_dir="/your/custom/path/here"

##================================================================================================



##================================================================================================
##------------------------------------------------------------------------------------------------
## The Business	- you shouldn't need to make edits below for typical use
##------------------------------------------------------------------------------------------------
##================================================================================================


## Unraid Default Directories: appdata, cert directory & filename suffix - as of Unraid 6.12
#		unraid_appdata="/mnt/user/appdata/"
#		unraid_certdir="/boot/config/ssl/certs/"
# 		unraid_certsuffix="_unraid_bundle.pem"

unraid_appdata="/mnt/user/appdata/"
unraid_certdir="/boot/config/ssl/certs/"
unraid_certsuffix="_unraid_bundle.pem"

## Certificate parent directory specified from the app' appdata directory (this differs based on the app/version installed)
#		NPM Official: "letsencrypt/archive/"
#		NPMPlus: "data/tls/certbot/archive/"

cert_parent_dir="letsencrypt/archive/"


## Certificate filename(s)
# 		For NPM certificate chain consists of 4 files inside a specific folder (see REQUIRED SETTINGS up above)
#
#		cert_file1="fullchain1.pem"		cert_file2="chain1.pem"		cert_file3="cert1.pem"		cert_file4="privkey21.pem"
#

cert_file1="fullchain1.pem"
cert_file2="chain1.pem"
cert_file3="cert1.pem"
cert_file4="privkey1.pem"

## pfSense filenames
#

## Traefik filenames
#


## If certificates are stored on a DIFFERENT host/server
#

if [ ! "$cert_server_name" = "remoteserver" ] && [ ! "$cert_server_name" = "" ] && [ ! "$cert_server_name" = "$this_server_name" ]; then
	self_serve="no"
else
	self_serve="yes"
fi


## Build the path variables
#	
#


if [ ! -z "$custom_cert_dir"]; then
	full_cert_path=$custom_cert_dir

elif [ $self_serve = "no" ]; then
	# make server name UPPERCASE
	cert_server_name="${cert_server_name^^}"
	full_cert_path="/mnt/remotes/"${cert_server_name}"_appdata/"${app_dir}"/"${cert_parent_dir}${cert_dir}

else
	full_cert_path=${unraid_appdata}${app_dir}"/"${cert_parent_dir}${cert_dir}

fi



##================================================================================================
# Copy the files and display confirmation messages
#

unraid_cert_file="${this_server_name}${unraid_certsuffix}"

printf "\n\n"

## Validate names, source path and certificate files
#

if [ "$this_server_name" = "" ]; then
	printf "\n❗❗ The server name has been left blank - please enter the name of this server at under the script's Required Settings.\n\n"
	error=1
fi

if [ ! -d "${full_cert_path}" ]; then
  printf "\n❗❗ The source certificates directory can't be found. Make sure the script variables have been edited correctly\n"
  printf "\nDirectory: \"${full_cert_path}\"\n"
	error=1
else
	cd ${full_cert_path}
fi

if [ ! -f "$cert_file1" ] || [ ! -f "$cert_file2" ] || [ ! -f "$cert_file3" ] || [ ! -f "$cert_file4" ]; then
	printf "\n❗❗ One or more of the original certificate files can't be found. Check your edits in the script.\n\n"
  	printf "\nLooking in directory: \"${full_cert_path}\"\n"
  	error=1
fi

if [ ! -d "${unraid_certdir}" ]; then
	printf "\n❗❗ The Unraid certificate directory can't be found. Please check your edits in the script. /\n"
	printf "\nDirectory: \"${unraid_certdir}\"\n"
	error=1
fi

if [ $error ]; then
	exit 1
fi

## copy the original certificate files to the Unraid certificates path
#

tmp_originals="/tmp/original_certs"
mkdir -p $tmp_originals

cp * ${tmp_originals}
cd ${tmp_originals}

## Concatenate the original cert files into an Unraid certificate bundle
# 

if [ ! -f "$cert_file1" ] || [ ! -f "$cert_file2" ] || [ ! -f "$cert_file3" ] || [ ! -f "$cert_file4" ]; then
	printf "\n❗❗ There was a problem copying the certificate files - please contact the script developer\n\n"
	exit 1
else
	cat $cert_file1 $cert_file2 $cert_file3 $cert_file4 > bundle.pem
fi

## Copy the new bundle to the Unraid cerftificate directory
# 

if [ ! -f bundle.pem ]; then
	printf "\n❗❗ There was a problem creating the Unraid Certificate Bundle - please contact the script developer\n\n"
	exit 1
else
	cp bundle.pem ${unraid_certdir}${unraid_cert_file}
fi

##  Adjust file permissions to creator-only read-write
#

chmod 600 ${unraid_certdir}${unraid_cert_file}

#rm -r $tmp_originals

printf "Success!\n"
printf "\nYour TLS/SSL Certificate has been created and copied to ${unraid_cert_file}\n"

## Restart the Unraid WebUI
#

printf "\nThe Unraid WebUI is reloading its configuration with your new certificate.\n\n\n"
/etc/rc.d/rc.nginx reload

