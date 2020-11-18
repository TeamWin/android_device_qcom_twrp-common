# TWRP standard device files for Qualcomm SoCs

This device tree is made for Qualcomm devices which need working decryption in TWRP. It includes the necessary services and prepdecrypt script so that these do not need to be included in the device tree.

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

If for some reason these scripts do not work for you, increase the loglevel to `2` in [prepdecrypt.sh](https://github.com/TeamWin/android_device_qcom_twrp-common/blob/android-8.1/crypto/sbin/prepdecrypt.sh#L22) and review the additional logging in the recovery.log to see where the process is failing.

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
