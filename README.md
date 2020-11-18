# TWRP standard device files for Qualcomm SoCs

This device tree is made for Qualcomm devices which need working decryption in TWRP. It includes the necessary services and prepdecrypt script so that these do not need to be included in the device tree.

## Prerequisites
- TWRP device tree with necessary vendor service binaries and dependencies<sup>*</sup> already included
  ```
  FDE binaries: qseecomd, keymaster(3.0/4.0)
  FBE binaries: FDE binaries + gatekeeper(1.0)
  ```
  ><sup>*</sup> To find the necessary dependencies for the above binaries, a tool like @that1's [ldcheck](https://github.com/that1/ldcheck) can be used.
- init.recovery.$(ro.hardware).rc file in device tree with symlink for bootdevice included
  ```
  symlink /dev/block/platform/soc/${ro.boot.bootdevice} /dev/block/bootdevice
  ```
**NOTES:**
- In the Android 8.1 & 9.0 trees, the binaries should be placed in the recovery ramdisk (recovery/root) in the same location as in the stock ROM, i.e. vendor/bin(/hw).
- In the Android 10 tree, the binaries should be placed in system/bin.

## TWRP Common Decryption files
To include these files for your device, the following BoardConfig flags should be used (only one flag is needed in either case, not both):
### FDE Devices
- BOARD_USES_QCOM_DECRYPTION := true
### FBE Devices
- BOARD_USES_QCOM_FBE_DECRYPTION := true
### Other Device Tree Updates
The packages will need to be added to the device tree device.mk as indicated below:
```
PRODUCT_PACKAGES += \
    qcom_decrypt \
    qcom_decrypt_fbe
```
Only the `qcom_decrypt` package should be included for FDE devices, and both should be included for FBE devices.

To import the decryption rc files into your device tree, add this line to your `init.recovery.$(ro.hardware).rc` file:
```
import /init.recovery.qcom_decrypt.rc
```

If you forget to add the above import, the build tree will add it for you if it can find the `init.recovery.qcom.rc` file. Otherwise, there will be a warning near the end of the build system output that the import needs to be added.

If for some reason these scripts do not work for you, increase the loglevel to `2` in [prepdecrypt.sh](https://github.com/TeamWin/android_device_qcom_twrp-common/blob/android-9.0/crypto/sbin/prepdecrypt.sh#L22) and review the additional logging in the recovery.log to see where the process is failing.

### tzdata package
The tree also provides a package to add tzdata to the TWRP tree, to get rid of these errors:
```
__bionic_open_tzdata: couldn't find any tzdata when looking for xxxxx
```

To include tzdata in your TWRP build, add the corresponding package to your device.mk as indicated below:
```
PRODUCT_PACKAGES += \
    tzdata_twrp
```

## Example Device Trees
- android-8.1: [HTC U12+](https://github.com/TeamWin/android_device_htc_ime/tree/android-8.1/recovery/root)
- android-9.0: [ASUS ROG Phone II](https://github.com/CaptainThrowback/android_device_asus_I001D/tree/android-9.0/recovery/root)
- android-10: [ASUS ROG Phone 3/ZenFone 7 Series](https://github.com/CaptainThrowback/android_device_asus_sm8250-common/tree/android-10/recovery/root)
