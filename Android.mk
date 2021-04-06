#
# Copyright (C) 2020 Captain_Throwback
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

LOCAL_PATH := $(call my-dir)

ifeq ($(BOARD_USES_QCOM_FBE_DECRYPTION),true)
    BOARD_USES_QCOM_DECRYPTION := true

    # Dummy file to apply post-install patch for qcom_decrypt_fbe
    include $(CLEAR_VARS)

    LOCAL_MODULE := qcom_decrypt_fbe
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)/system/bin
    LOCAL_REQUIRED_MODULES := qcom_decrypt

    # Cannot send to TARGET_RECOVERY_ROOT_OUT since build system wipes init*.rc
    # during ramdisk creation and only allows init.recovery.*.rc files to be copied
    # from TARGET_ROOT_OUT thereafter
    LOCAL_POST_INSTALL_CMD += \
        cp -f $(LOCAL_PATH)/crypto_fbe/init.recovery* $(TARGET_ROOT_OUT); \
        bash $(LOCAL_PATH)/scripts/service_cleanup.bash; \
        bash $(LOCAL_PATH)/scripts/create_manifests.bash
    include $(BUILD_PHONY_PACKAGE)
endif

ifeq ($(BOARD_USES_QCOM_DECRYPTION),true)
    # Include resetprop for prepdecrypt property setting
    TW_INCLUDE_RESETPROP := true

    # Dummy file to apply post-install patch for qcom_decrypt
    include $(CLEAR_VARS)

    LOCAL_MODULE := qcom_decrypt
    LOCAL_MODULE_TAGS := optional
    LOCAL_MODULE_CLASS := ETC
    LOCAL_MODULE_PATH := $(TARGET_ROOT_OUT)/system/bin
    LOCAL_REQUIRED_MODULES := android.hardware.boot@1.0 android.hidl.token@1.0 teamwin

    # Cannot send to TARGET_RECOVERY_ROOT_OUT since build system wipes init*.rc
    # during ramdisk creation and only allows init.recovery.*.rc files to be copied
    # from TARGET_ROOT_OUT thereafter
    LOCAL_POST_INSTALL_CMD += \
        if [ -e $(TARGET_ROOT_OUT)/init.recovery.qcom.rc ]; then \
        grep -qF 'init.recovery.qcom_decrypt.rc' $(TARGET_ROOT_OUT)/init.recovery.qcom.rc || \
        echo -e '\nimport /init.recovery.qcom_decrypt.rc' >> $(TARGET_ROOT_OUT)/init.recovery.qcom.rc; \
        elif [ -e $(TARGET_RECOVERY_ROOT_OUT)/init.recovery.qcom.rc ]; then \
        grep -qF 'init.recovery.qcom_decrypt.rc' $(TARGET_RECOVERY_ROOT_OUT)/init.recovery.qcom.rc || \
        echo -e '\nimport /init.recovery.qcom_decrypt.rc' >> $(TARGET_RECOVERY_ROOT_OUT)/init.recovery.qcom.rc; \
        elif [ -e device/$(shell echo $(PRODUCT_BRAND) | tr  '[:upper:]' '[:lower:]')/$(TARGET_DEVICE)/recovery/root/init.recovery.qcom.rc ]; then \
        grep -qF 'init.recovery.qcom_decrypt.rc' device/$(shell echo $(PRODUCT_BRAND) | tr  '[:upper:]' '[:lower:]')/$(TARGET_DEVICE)/recovery/root/init.recovery.qcom.rc || \
        echo -e '\nimport /init.recovery.qcom_decrypt.rc' >> device/$(shell echo $(PRODUCT_BRAND) | tr  '[:upper:]' '[:lower:]')/$(TARGET_DEVICE)/recovery/root/init.recovery.qcom.rc; \
        else echo -e '\n*** init.recovery.qcom.rc not found ***\nYou will need to manually add the import for init.recovery.qcom_decrypt.rc to your init.recovery.(ro.hardware).rc file!!\n'; fi; \
        cp -Ra $(LOCAL_PATH)/crypto/system $(TARGET_ROOT_OUT)/;

    ifeq ($(PRODUCT_USE_DYNAMIC_PARTITIONS),true)
        LOCAL_POST_INSTALL_CMD += \
            cp -f $(LOCAL_PATH)/crypto/init.recovery.qcom_decrypt.rc $(TARGET_ROOT_OUT)/;
    else
        LOCAL_POST_INSTALL_CMD += \
            cp -f $(LOCAL_PATH)/crypto/init.recovery.qcom_decrypt.rc $(TARGET_ROOT_OUT)/; \
            sed -i 's/on property:ro.crypto.state=encrypted && property:ro.boot.dynamic_partitions=true/on property:ro.crypto.state=encrypted/' $(TARGET_ROOT_OUT)/init.recovery.qcom_decrypt.rc;
    endif
    ifeq ($(BOARD_USES_QCOM_FBE_DECRYPTION),)
        LOCAL_POST_INSTALL_CMD += \
            bash $(LOCAL_PATH)/scripts/service_cleanup.bash; \
            bash $(LOCAL_PATH)/scripts/create_manifests.bash
    endif
    include $(BUILD_PHONY_PACKAGE)
endif
