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
	included_blobs=($(find "$blob_path" -type f \( -name "*keymaster*" -o -name "*gatekeeper*" -o -name "*boot*-service" \) | awk -F'/' '{print $NF}'))
	if [ -e "$vendorout" ]; then
		included_blobs+=($(find "$vendorout" -type f -name "android.hardware.boot*-service" | awk -F'/' '{print $NF}'))
	fi
	included_blobs+=($(find "$dt_ramdisk" -type f -name "android.hardware.boot*-service" | awk -F'/' '{print $NF}'))
	included_blobs_uniq=($(printf "%s\n" "${included_blobs[@]}" | sort -u))
}

generate_manifests()
{
	mkdir -p "$systemout"
	mkdir -p "$vendorout"
	system_manifest_file="$systemout/manifest.xml"
	vendor_manifest_file="$vendorout/manifest.xml"
	echo -e '<manifest version="1.0" type="">' > "$system_manifest_file"
	echo -e '<manifest version="1.0" type="">' > "$vendor_manifest_file"
	for blob in "${included_blobs_uniq[@]}"; do
		case $blob in
			*.so)
				manifest_file="$system_manifest_file"
				manifest_type="framework"
				blob_name=$(basename "$blob" .so)
				;;
			*-service*)
				manifest_file="$vendor_manifest_file"
				manifest_type="device"
				blob_name=$(echo "${blob%-service*}")
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
			*boot*)
				interface_name="IBootControl"
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
	echo -e '</manifest>' >> "$system_manifest_file"
	echo -e '</manifest>' >> "$vendor_manifest_file"
}

oem=$(find "$PWD/device" -type d -name "$CUSTOM_BUILD" | sed -E "s/.*device\/(.*)\/$target_device.*/\1/")
dt_ramdisk="$PWD/device/$oem/$CUSTOM_BUILD/recovery/root"
recoveryout="$OUT/recovery/root"
rootout="$OUT/root"
sysbin="system/bin"
systemout="$OUT/system"
venbin="vendor/bin"
vendorout="$OUT/vendor"
decrypt_fbe_rc="init.recovery.qcom_decrypt.fbe.rc"

case $TARGET_PLATFORM_VERSION in
	R*)
		sdkver=30
		;;
	Q*)
		sdkver=29
		;;
	P*)
		sdkver=28
		;;
	O*)
		sdkver=27
		;;
esac

echo " "
echo "Running $SCRIPTNAME script for Qcom decryption..."
echo -e "SDK version: $sdkver\n"

if [ -e "$rootout/$decrypt_fbe_rc" ]; then
	is_fbe=true
	echo -e "FBE Status: $is_fbe\n"
	decrypt_fbe_rc="$rootout/$decrypt_fbe_rc"
fi

# pull filenames for included services
if [ "$sdkver" -lt 29 ]; then
	# android-8.1/9.0 branches
	find_dt_blobs "$venbin"
else
	# android 10.0/11 branches
	find_dt_blobs "$sysbin"
fi
if [ -z "$included_blobs_uniq" ]; then
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
included_blobs_uniq+=($(echo ${hidl_blobs_uniq[@]}))
echo "All blobs:"
printf '%s\n' "${included_blobs_uniq[@]}"

# Create manifest files
generate_manifests

# Copy the manifests
if [ -e "$recoveryout/system_root" ]; then
	cp -f "$system_manifest_file" "$recoveryout/system_root/system/"
else
	cp -f "$system_manifest_file" "$recoveryout/system/"
fi
mkdir -p "$recoveryout/vendor"
cp -f "$vendor_manifest_file" "$recoveryout/vendor/"

echo " "
echo -e "$SCRIPTNAME script complete.\n"
