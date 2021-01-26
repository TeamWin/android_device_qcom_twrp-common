#!/bin/bash

SCRIPTNAME="Service_Cleanup"

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

find_service_names()
{
	service_name=($(grep -E "$service( |$)" "$decrypt_rc" | sed -E "s/.*service (.*) \/$1.*/\1/"))
	if [ "$is_fbe" = "true" ]; then
		service_name+=($(grep -E "$service( |$)" "$decrypt_fbe_rc" | sed -E "s/.*service (.*) \/$1.*/\1/"))
	fi
}

# remove_line <file> <line match string> <scope>
remove_line() {
  local lines line;
  if grep -q "$2" $1; then
    lines=$(grep -E -n "$2" $1 | cut -d: -f1 | sort -nr);
    [ "$3" = "global" ] || lines=$(echo "$lines" | tail -n1);
    for line in $lines; do
      sed -i "${line}d" $1;
    done;
  fi;
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
decrypt_rc="init.recovery.qcom_decrypt.rc"
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
echo -e "SDK version: $sdkver"

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
	exit 2
fi

# pull filenames from init.recovery.qcom_decrypt.rc & init.recovery.qcom_decrypt.fbe files
decrypt_rc="$rootout/$decrypt_rc"
rc_service_paths=($(grep '^service.*keymaster' "$decrypt_rc" | awk -F'/' '{print $NF}'))
if [ "$is_fbe" = "true" ]; then
	rc_service_paths+=($(grep '^service.*gatekeeper' "$decrypt_fbe_rc" | awk -F'/' '{print $NF}'))
fi
echo "Services in rc file:"
printf '%s\n' "${rc_service_paths[@]}"
echo " "

# find services in rc file not included in build
services_not_included=($(echo "${rc_service_paths[@]}" "${included_blobs[@]}" | tr ' ' '\n' | sort | uniq -u))
echo "Services not included:"
printf '%s\n' "${services_not_included[@]}"
echo " "

# remove unneeded services
for service in ${services_not_included[@]}; do
	if [ "$sdkver" -lt 29 ]; then
		# android 9.0 branch
		find_service_names "sbin"
	else
		# android 10.0 branch
		find_service_names "system"
	fi
	echo "Removing unneeded service: ${service_name[*]}"
	case ${service_name[@]} in
		gatekeeper*)
			remove_section "$decrypt_fbe_rc" "$service"
			remove_line "$decrypt_fbe_rc" "$service_name$" "global"
			;;
		keymaster*)
			remove_section "$decrypt_rc" "$service"
			remove_line "$decrypt_rc" "$service_name$" "global"
			if [ "$is_fbe" = "true" ]; then
				remove_line "$decrypt_fbe_rc" "$service_name$" "global"
			fi
			;;
		*)
			continue
			;;
	esac
done

echo " "
echo -e "$SCRIPTNAME script complete.\n"
