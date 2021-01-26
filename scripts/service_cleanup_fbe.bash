#!/bin/bash

SCRIPTNAME="Service_Cleanup_FBE"

# remove_line <file> <line match string>
remove_line() {
  sed -i -e "/$2$/d" "$1"
}

# remove_section <file> <begin search string> <end search string>
remove_section() {
  local begin endstr last end;
  begin=$(grep -n "$2" $1 | head -n1 | cut -d: -f1);
  if [ "$begin" ]; then
    if [ "$3" = " " -o ! "$3" ]; then
      endstr='^[[:space:]]*$';
      last=$(wc -l $1 | cut -d\  -f1);
    else
      endstr="$3";
    fi;
    for end in $(grep -n "$endstr" $1 | cut -d: -f1) $last; do
      if [ "$end" ] && [ "$begin" -lt "$end" ]; then
        sed -i "${begin},${end}d" $1;
        break;
      fi;
    done;
  fi;
}

oem=$(find "$PWD/device" -type d -name "$CUSTOM_BUILD" | sed -E "s/.*device\/(.*)\/$target_device.*/\1/")
dt_ramdisk="$PWD/device/$oem/$CUSTOM_BUILD/recovery/root"
rootout="$OUT/root"
recoveryout="$OUT/recovery/root"
sysbin="system/bin"
venbin="vendor/bin"
decrypt_rc="init.recovery.qcom_decrypt.fbe.rc"

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

# pull filenames for included services
if [ "$sdkver" -lt 29 ]; then
	# android-8.1/9.0 branches
	if [ -e "$recoveryout/$venbin/qseecomd" ]; then
		venbin="$recoveryout/$venbin"
	else
		venbin="$dt_ramdisk/$venbin"
	fi
	included_blobs=($(find "$venbin" -type f -exec echo '{}' \; | awk -F'/' '{print $NF}' | grep gatekeeper))
else
	# android 10.0/11 branches
	if [ -e "$recoveryout/$sysbin/qseecomd" ]; then
		sysbin="$recoveryout/$sysbin"
	else
		sysbin="$dt_ramdisk/$sysbin"
	fi
	included_blobs=($(find "$sysbin" -type f -exec echo '{}' \; | awk -F'/' '{print $NF}' | grep gatekeeper))
fi
echo "Blobs parsed:"
printf '%s\n' "${included_blobs[@]}"
echo " "

# pull filenames from init.recovery.qcom_decrypt.rc file
decrypt_rc="$rootout/$decrypt_rc"
rc_service_paths=($(grep "service " "$decrypt_rc" | awk -F'/' '{print $NF}' | grep gatekeeper))
echo "Services in rc file:"
printf '%s\n' "${rc_service_paths[@]}"
echo " "

# find services in rc file not included in build
services_not_included=($(echo ${rc_service_paths[@]} ${included_blobs[@]} | tr ' ' '\n' | sort | uniq -u))
echo "Services not included:"
printf '%s\n' "${services_not_included[@]}"
echo " "

# remove unneeded services
for service in ${services_not_included[@]}; do
	if [ "$sdkver" -lt 29 ]; then
		# android 9.0 branch
		service_name=$(grep -E "$service( |$)" "$decrypt_rc" | sed -E 's/.*service (.*) \/sbin.*/\1/')
	else
		# android 10.0 branch
		service_name=($(grep -E "$service( |$)" "$decrypt_rc" | sed -E 's/.*service (.*) \/system.*/\1/'))
	fi
	case ${service_name[@]} in
		gatekeeper*)
			echo "Removing unneeded service: $service_name"
			remove_section "$decrypt_rc" "$service" "u:r:recovery:s0"
			remove_line "$decrypt_rc" "$service_name"
			;;
	esac
done

echo " "
echo -e "$SCRIPTNAME script complete.\n"
