#!/bin/bash

SCRIPTNAME="Create_Manifests"

find_dt_blobs()
{
	if [ -e "$recoveryout/$1/qseecomd" ]; then
		blob_path="$recoveryout/$1"
	elif [ -e "$dt_ramdisk/$1/qseecomd" ]; then
		blob_path="$dt_ramdisk/$1"
	else
		echo "Unable to locate device tree blobs."
		echo " "
	fi
	included_blobs=($(find "$blob_path" -type f \( -name "*keymaster*" -o -name "*gatekeeper*" \) | awk -F'/' '{print $NF}'))
}

generate_manifests()
{
	mkdir -p "$systemout/$manifest_folder"
	mkdir -p "$vendorout/$manifest_folder"
	system_manifest_file="$systemout/$manifest_folder/manifest.xml"
	vendor_manifest_file="$vendorout/$manifest_folder/manifest.xml"
	if [ -e "$system_manifest_file" ]; then
		system_manifest_exists=true
		echo "System manifest file already exists. Skipping file generation."
	else
		echo -e '<manifest version="2.0" type="">' > "$system_manifest_file"
	fi
	if [ -e "$vendor_manifest_file" ]; then
		vendor_manifest_exists=true
		echo "Vendor manifest file already exists. Skipping file generation."
	else
		echo -e '<manifest version="2.0" type="" target-level="5">' > "$vendor_manifest_file"
	fi
	for blob in "${included_blobs[@]}"; do
		case $blob in
			*.so)
				if [ -z "$system_manifest_exists" ]; then
					manifest_file="$system_manifest_file"
					manifest_type="framework"
					blob_name=$(basename "$blob" .so)
				else
					break
				fi
				;;
			*-service*)
				if [ -z "$vendor_manifest_exists" ]; then
					manifest_file="$vendor_manifest_file"
					manifest_type="device"
					blob_name=$(echo "${blob%-service*}")
				else
					break
				fi
				;;
		esac
		sed -i "s/type=\"\"/type=\"$manifest_type\"/" "$manifest_file"
		echo -e '\t<hal format="hidl">' >> "$manifest_file"
		service_name=$(echo "${blob%%@*}")
		echo -e "\t\t<name>$service_name</name>" >> "$manifest_file"
		echo -e '\t\t<transport>hwbinder</transport>' >> "$manifest_file"
		service_version=$(echo "${blob_name#*@}")
		echo -e "\t\t<version>$service_version</version>" >> "$manifest_file"
		echo -e '\t\t<interface>' >> "$manifest_file"
		case $service_name in
			*base*)
				interface_name="IBase"
				;;
			*gatekeeper*)
				interface_name="IGatekeeper"
				;;
			*keymaster*)
				interface_name="IKeymasterDevice"
				;;
			*manager*)
				interface_name="IServiceManager"
				;;
			*token*)
				interface_name="ITokenManager"
				;;
		esac
		echo -e "\t\t\t<name>$interface_name</name>" >> "$manifest_file"
		echo -e '\t\t\t<instance>default</instance>' >> "$manifest_file"
		echo -e '\t\t</interface>' >> "$manifest_file"
		echo -e "\t\t<fqname>@$service_version::$interface_name/default</fqname>" >> "$manifest_file"
		echo -e '\t</hal>' >> "$manifest_file"
	done
	if [ -z "$system_manifest_exists" ]; then
		echo -e '</manifest>' >> "$system_manifest_file"
	fi
	if [ -z "$vendor_manifest_exists" ]; then
		echo -e '</manifest>' >> "$vendor_manifest_file"
	fi
}

echo " "
echo -e "Running $SCRIPTNAME script for Qcom decryption...\n"

target_device=${TARGET_PRODUCT#*_}

# Define OUT folder
if [ "$PWD" = "/builds/min-aosp11" ]; then
	OUT="/builds/out/target/product/$target_device"
else
	OUT="$PWD/out/target/product/$target_device"
fi
echo -e "OUT Folder set to: $OUT"

oem=$(find "$PWD/device" -type d -name "$target_device" | sed -E "s/.*device\/(.*)\/$target_device.*/\1/")
dt_ramdisk="$PWD/device/$oem/$target_device/recovery/root"
recoveryout="$OUT/recovery/root"
rootout="$OUT/root"
sysbin="system/bin"
systemout="$OUT/system"
vendorout="$OUT/vendor"
manifest_folder="etc/vintf"
decrypt_fbe_rc="init.recovery.qcom_decrypt.fbe.rc"

if [ -e "$rootout/$decrypt_fbe_rc" ]; then
	is_fbe=true
	echo -e "FBE Status: $is_fbe\n"
	decrypt_fbe_rc="$rootout/$decrypt_fbe_rc"
fi

# pull filenames for included services
# android 10.0/11 branches
find_dt_blobs "$sysbin"
if [ -z "$included_blobs" ]; then
	echo "No keymaster/gatekeeper blobs present."
	echo " "
fi

# Pull filenames for included hidl blobs
hidl_blobs=($(find "$systemout" -type f -name "android.hidl*.so" | awk -F'/' '{print $NF}'))
hidl_blobs+=($(find "$dt_ramdisk" -type f -name "android.hidl*.so" | awk -F'/' '{print $NF}'))
if [ -n "$hidl_blobs" ]; then
	hidl_blobs_uniq=($(printf "%s\n" "${hidl_blobs[@]}" | sort -u))
else
	echo "No HIDL blobs found."
	echo " "
fi

# Combine blobs into a single array
included_blobs+=($(echo ${hidl_blobs_uniq[@]}))
echo "All blobs:"
printf '%s\n' "${included_blobs[@]}"

# Create manifest files
generate_manifests

# Copy the manifests
if [ -z "$system_manifest_exists" ]; then
	if [ -e "$recoveryout/system_root" ]; then
		mkdir -p "$recoveryout/system_root/system/$manifest_folder/"
		cp -f "$system_manifest_file" "$recoveryout/system_root/system/$manifest_folder/"
	else
		mkdir -p "$recoveryout/system/$manifest_folder/"
		cp -f "$system_manifest_file" "$recoveryout/system/$manifest_folder/"
	fi
fi
if [ -z "$vendor_manifest_exists" ]; then
	mkdir -p "$recoveryout/vendor/$manifest_folder"
	cp -f "$vendor_manifest_file" "$recoveryout/vendor/$manifest_folder/"
fi

echo " "
echo -e "$SCRIPTNAME script complete.\n"
