#!/bin/bash

SCRIPTNAME="Create_Manifests"

find_dt_blobs()
{
	if [ -e "$recoveryout/$1/qseecomd" ]; then
		blob_path="$recoveryout/$1"
	elif [ -e "$dt_ramdisk/$1/qseecomd" ]; then
		blob_path="$dt_ramdisk/$1"
	else
		echo "Unable to locate device tree blobs. Exiting script."
		exit 1
	fi
	included_blobs=($(find "$blob_path" -type f \( -name "*keymaster*" -o -name "*gatekeeper*" \) | awk -F'/' '{print $NF}'))
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
if [ -n "$included_blobs" ]; then
	echo "Blobs parsed:"
	printf '%s\n' "${included_blobs[@]}"
	echo " "
else
	echo "No blobs parsed! Exiting script."
	exit 1
fi

syslib="lib"
abi="$PROMPT_COMMAND"
case "$abi" in
	*64*)
		syslib="lib64"
		;;
esac

# Pull filenames for included hidl blobs
hidl_blobs=($(find "$systemout/$syslib" -type f -name "android.hidl*.so" | awk -F'/' '{print $NF}'))
if [ -n "$hidl_blobs" ]; then
	echo "HIDL blobs parsed:"
	printf '%s\n' "${hidl_blobs[@]}"
else
	hidl_blobs=($(find "$dt_ramdisk" -type f -name "android.hidl*.so" | awk -F'/' '{print $NF}'))
	if [ -n "$hidl_blobs" ]; then
		echo "HIDL blobs parsed:"
		printf '%s\n' "${hidl_blobs[@]}"
	else
		echo "No HIDL blobs found."
	fi
fi

# Create system manifest file
system_manifest_file="$systemout/manifest.xml"
echo -e '<manifest version="1.0" type="framework">' > "$system_manifest_file"
for blob in ${hidl_blobs[@]}; do
	echo -e '\t<hal format="hidl">' >> "$system_manifest_file"
	service_name=$(echo "${blob%%@*}")
	echo -e "\t\t<name>$service_name</name>" >> "$system_manifest_file"
	echo -e '\t\t<transport>hwbinder</transport>' >> "$system_manifest_file"
	blob_name=$(basename "$blob" .so)
	service_version=$(echo "${blob_name#*@}")
	echo -e "\t\t<version>$service_version</version>" >> "$system_manifest_file"
	echo -e '\t\t<interface>' >> "$system_manifest_file"
	case $service_name in
		*base*)
			interface_name="IBase"
			;;
		*token*)
			interface_name="ITokenManager"
			;;
		*manager*)
			interface_name="IServiceManager"
			;;
	esac
	echo -e "\t\t\t<name>$interface_name</name>" >> "$system_manifest_file"
	echo -e '\t\t\t<instance>default</instance>' >> "$system_manifest_file"
	echo -e '\t\t</interface>' >> "$system_manifest_file"
	echo -e "\t\t<fqname>@$service_version::$interface_name/default</fqname>" >> "$system_manifest_file"
	echo -e '\t</hal>' >> "$system_manifest_file"
done
echo -e '</manifest>' >> "$system_manifest_file"

# Create vendor manifest file
vendor_manifest_file="$vendorout/manifest.xml"
echo -e '<manifest version="1.0" type="device">' > "$vendor_manifest_file"
for blob in ${included_blobs[@]}; do
	echo -e '\t<hal format="hidl">' >> "$vendor_manifest_file"
	service_name=$(echo "${blob%%@*}")
	echo -e "\t\t<name>$service_name</name>" >> "$vendor_manifest_file"
	echo -e '\t\t<transport>hwbinder</transport>' >> "$vendor_manifest_file"
	blob_name=$(echo "${blob%-service*}")
	service_version=$(echo "${blob_name#*@}")
	echo -e "\t\t<version>$service_version</version>" >> "$vendor_manifest_file"
	echo -e '\t\t<interface>' >> "$vendor_manifest_file"
	case $service_name in
		*keymaster*)
			interface_name="IKeymasterDevice"
			;;
		*gatekeeper*)
			interface_name="IGatekeeper"
			;;
	esac
	echo -e "\t\t\t<name>$interface_name</name>" >> "$vendor_manifest_file"
	echo -e '\t\t\t<instance>default</instance>' >> "$vendor_manifest_file"
	echo -e '\t\t</interface>' >> "$vendor_manifest_file"
	echo -e "\t\t<fqname>@$service_version::$interface_name/default</fqname>" >> "$vendor_manifest_file"
	echo -e '\t</hal>' >> "$vendor_manifest_file"
done
echo -e '</manifest>' >> "$vendor_manifest_file"

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
