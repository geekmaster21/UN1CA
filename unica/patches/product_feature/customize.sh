# [
DECOMPILE()
{
    if [ ! -d "$APKTOOL_DIR/$1" ]; then
        bash "$SRC_DIR/scripts/apktool.sh" d "$1"
    fi
}

APPLY_PATCH()
{
    local PATCH
    local OUT

    DECOMPILE "$1"

    cd "$APKTOOL_DIR/$1"
    PATCH="$SRC_DIR/unica/patches/product_feature/$2"
    OUT="$(patch -p1 -s -t -N --dry-run < "$PATCH")" \
        || echo "$OUT" | grep -q "Skipping patch" || false
    patch -p1 -s -t -N --no-backup-if-mismatch < "$PATCH" &> /dev/null || true
    cd - &> /dev/null
}

GET_FP_SENSOR_TYPE()
{
    if [[ "$1" == *"ultrasonic"* ]]; then
        echo "ultrasonic"
    elif [[ "$1" == *"optical"* ]]; then
        echo "optical"
    elif [[ "$1" == *"side"* ]]; then
        echo "side"
    else
        echo "Unsupported type: $1"
        exit 1
    fi
}
# ]

if [[ "$SOURCE_PRODUCT_FIRST_API_LEVEL" != "$TARGET_PRODUCT_FIRST_API_LEVEL" ]]; then
    echo "Applying MAINLINE_API_LEVEL patches"

    DECOMPILE "system/framework/esecomm.jar"
    DECOMPILE "system/framework/services.jar"

    FTP="
    system/framework/esecomm.jar/smali/com/sec/esecomm/EsecommAdapter.smali
    system/framework/services.jar/smali/com/android/server/SystemServer.smali
    system/framework/services.jar/smali_classes2/com/android/server/enterprise/hdm/HdmVendorController.smali
    system/framework/services.jar/smali_classes2/com/android/server/knox/dar/ddar/ta/TAProxy.smali
    system/framework/services.jar/smali_classes3/com/android/server/power/PowerManagerUtil.smali
    "

    for f in $FTP; do
        sed -i "s/\"$SOURCE_PRODUCT_FIRST_API_LEVEL\"/\"$TARGET_PRODUCT_FIRST_API_LEVEL\"/g" "$APKTOOL_DIR/$f"
    done
fi

if [[ "$SOURCE_AUTO_BRIGHTNESS_TYPE" != "$TARGET_AUTO_BRIGHTNESS_TYPE" ]]; then
    echo "Applying auto brightness type patches"

    DECOMPILE "system/framework/services.jar"
    DECOMPILE "system/framework/ssrm.jar"

    FTP="
    system/framework/services.jar/smali_classes3/com/android/server/power/PowerManagerUtil.smali
    system/framework/ssrm.jar/smali/com/android/server/ssrm/PreMonitor.smali
    "

    for f in $FTP; do
        sed -i "s/\"$SOURCE_AUTO_BRIGHTNESS_TYPE\"/\"$TARGET_AUTO_BRIGHTNESS_TYPE\"/g" "$APKTOOL_DIR/$f"
    done
fi

if [[ "$(GET_FP_SENSOR_TYPE "$SOURCE_FP_SENSOR_CONFIG")" != "$(GET_FP_SENSOR_TYPE "$TARGET_FP_SENSOR_CONFIG")" ]]; then
    echo "Applying fingerprint sensor patches"

    DECOMPILE "system/framework/framework.jar"
    DECOMPILE "system/framework/services.jar"
    DECOMPILE "system/priv-app/SecSettings/SecSettings.apk"

    FTP="
    system/framework/framework.jar/smali_classes2/android/hardware/fingerprint/FingerprintManager.smali
    system/framework/framework.jar/smali_classes5/com/samsung/android/bio/fingerprint/SemFingerprintManager.smali
    system/framework/framework.jar/smali_classes5/com/samsung/android/bio/fingerprint/SemFingerprintManager\$Characteristics.smali
    system/framework/framework.jar/smali_classes5/com/samsung/android/rune/CoreRune.smali
    system/framework/services.jar/smali/com/android/server/biometrics/sensors/fingerprint/FingerprintUtils.smali
    system/priv-app/SecSettings/SecSettings.apk/smali_classes4/com/samsung/android/settings/biometrics/fingerprint/FingerprintSettingsUtils.smali
    "
    for f in $FTP; do
        sed -i "s/$SOURCE_FP_SENSOR_CONFIG/$TARGET_FP_SENSOR_CONFIG/g" "$APKTOOL_DIR/$f"
    done

    # TODO: handle ultrasonic devices
    if [[ "$(GET_FP_SENSOR_TYPE "$TARGET_FP_SENSOR_CONFIG")" == "optical" ]]; then
        cp -a --preserve=all "$SRC_DIR/unica/patches/product_feature/fingerprint/optical_fod/system/"* "$WORK_DIR/system/system"
    elif [[ "$(GET_FP_SENSOR_TYPE "$TARGET_FP_SENSOR_CONFIG")" == "side" ]]; then
        cp -a --preserve=all "$SRC_DIR/unica/patches/product_feature/fingerprint/side_fp/system/"* "$WORK_DIR/system/system"
    fi

    if [[ "$TARGET_FP_SENSOR_CONFIG" == *"navi=1"* ]]; then
        APPLY_PATCH "system/framework/services.jar" \
            "fingerprint/services.jar/0001-Enable-FP_FEATURE_GESTURE_MODE.patch"
    fi
    if [[ "$TARGET_FP_SENSOR_CONFIG" == *"no_delay_in_screen_off"* ]]; then
        APPLY_PATCH "system/priv-app/BiometricSetting/BiometricSetting.apk" \
            "fingerprint/BiometricSetting.apk/0001-Enable-FP_FEATURE_NO_DELAY_IN_SCREEN_OFF.patch"
    fi
fi


if [[ "$SOURCE_MDNIE_SUPPORTED_MODES" != "$TARGET_MDNIE_SUPPORTED_MODES" ]] || \
    [[ "$SOURCE_MDNIE_WEAKNESS_SOLUTION_FUNCTION" != "$TARGET_MDNIE_WEAKNESS_SOLUTION_FUNCTION" ]]; then
    echo "Applying mDNIe features patches"

    DECOMPILE "system/framework/services.jar"

    FTP="
    system/framework/services.jar/smali_classes2/com/samsung/android/hardware/display/SemMdnieManagerService.smali
    "

    for f in $FTP; do
        sed -i "s/\"$SOURCE_MDNIE_SUPPORTED_MODES\"/\"$TARGET_MDNIE_SUPPORTED_MODES\"/g" "$APKTOOL_DIR/$f"
        sed -i "s/\"$SOURCE_MDNIE_WEAKNESS_SOLUTION_FUNCTION\"/\"$TARGET_MDNIE_WEAKNESS_SOLUTION_FUNCTION\"/g" "$APKTOOL_DIR/$f"
    done
fi
if $SOURCE_HAS_HW_MDNIE; then
    if ! $TARGET_HAS_HW_MDNIE; then
        echo "Applying HW mDNIe patches"
        APPLY_PATCH "system/framework/framework.jar" "mdnie/framework.jar/0001-Disable-HW-mDNIe.patch"
        APPLY_PATCH "system/framework/services.jar" "mdnie/services.jar/0001-Disable-HW-mDNIe.patch"
    fi
else
    if $TARGET_HAS_HW_MDNIE; then
        # TODO: add HW mDNIe support
        true
    fi
fi

if [[ "$SOURCE_HFR_MODE" != "$TARGET_HFR_MODE" ]]; then
    echo "Applying HFR_MODE patches"

    DECOMPILE "system/framework/framework.jar"
    DECOMPILE "system/framework/gamemanager.jar"
    DECOMPILE "system/framework/gamesdk.jar"
    DECOMPILE "system/framework/secinputdev-service.jar"
    DECOMPILE "system/priv-app/SettingsProvider/SettingsProvider.apk"

    FTP="
    system/framework/framework.jar/smali_classes5/com/samsung/android/hardware/display/RefreshRateConfig.smali
    system/framework/framework.jar/smali_classes5/com/samsung/android/rune/CoreRune.smali
    system/framework/gamemanager.jar/smali/com/samsung/android/game/GameManagerService.smali
    system/framework/gamesdk.jar/smali/com/samsung/android/gamesdk/vrr/GameSDKVrrManager.smali
    system/framework/secinputdev-service.jar/smali/com/samsung/android/hardware/secinputdev/SemInputDeviceManagerService.smali
    system/priv-app/SettingsProvider/SettingsProvider.apk/smali/com/android/providers/settings/DatabaseHelper.smali
    "
    for f in $FTP; do
        sed -i "s/\"$SOURCE_HFR_MODE\"/\"$TARGET_HFR_MODE\"/g" "$APKTOOL_DIR/$f"
    done
fi
if [[ "$SOURCE_HFR_SUPPORTED_REFRESH_RATE" != "$TARGET_HFR_SUPPORTED_REFRESH_RATE" ]]; then
    echo "Applying HFR_SUPPORTED_REFRESH_RATE patches"

    DECOMPILE "system/framework/framework.jar"

    FTP="
    system/framework/framework.jar/smali_classes5/com/samsung/android/hardware/display/RefreshRateConfig.smali
    "
    for f in $FTP; do
        sed -i "s/\"$SOURCE_HFR_SUPPORTED_REFRESH_RATE\"/\"$TARGET_HFR_SUPPORTED_REFRESH_RATE\"/g" "$APKTOOL_DIR/$f"
    done
fi
if [[ "$SOURCE_HFR_DEFAULT_REFRESH_RATE" != "$TARGET_HFR_DEFAULT_REFRESH_RATE" ]]; then
    echo "Applying HFR_DEFAULT_REFRESH_RATE patches"

    DECOMPILE "system/framework/framework.jar"
    DECOMPILE "system/priv-app/SettingsProvider/SettingsProvider.apk"

    FTP="
    system/framework/framework.jar/smali_classes5/com/samsung/android/hardware/display/RefreshRateConfig.smali
    system/priv-app/SettingsProvider/SettingsProvider.apk/smali/com/android/providers/settings/DatabaseHelper.smali
    "
    for f in $FTP; do
        sed -i "s/\"$SOURCE_HFR_DEFAULT_REFRESH_RATE\"/\"$TARGET_HFR_DEFAULT_REFRESH_RATE\"/g" "$APKTOOL_DIR/$f"
    done
fi
if [[ "$SOURCE_HFR_SEAMLESS_BRT" != "$TARGET_HFR_SEAMLESS_BRT" ]] || \
    [[ "$SOURCE_HFR_SEAMLESS_LUX" != "$TARGET_HFR_SEAMLESS_LUX" ]]; then
    echo "Applying HFR_SEAMLESS_BRT/HFR_SEAMLESS_LUX patches"

    if [[ "$TARGET_HFR_SEAMLESS_BRT" == "none" ]] && [[ "$TARGET_HFR_SEAMLESS_LUX" == "none" ]]; then
        APPLY_PATCH "system/framework/framework.jar" "hfr/framework.jar/0001-Remove-brightness-threshold-values.patch"
    else
        DECOMPILE "system/framework/framework.jar"

        FTP="
        system/framework/framework.jar/smali_classes5/com/samsung/android/hardware/display/RefreshRateConfig.smali
        "

        for f in $FTP; do
            sed -i "s/\"$SOURCE_HFR_SEAMLESS_BRT\"/\"$TARGET_HFR_SEAMLESS_BRT\"/g" "$APKTOOL_DIR/$f"
            sed -i "s/\"$SOURCE_HFR_SEAMLESS_LUX\"/\"$TARGET_HFR_SEAMLESS_LUX\"/g" "$APKTOOL_DIR/$f"
        done
    fi
fi

if [[ "$SOURCE_MULTI_MIC_MANAGER_VERSION" != "$TARGET_MULTI_MIC_MANAGER_VERSION" ]]; then
    echo "Applying SemMultiMicManager patches"

    DECOMPILE "system/framework/framework.jar"

    FTP="
    system/framework/framework.jar/smali_classes5/com/samsung/android/camera/mic/SemMultiMicManager.smali
    "
    for f in $FTP; do
        sed -i "s/$SOURCE_MULTI_MIC_MANAGER_VERSION/$TARGET_MULTI_MIC_MANAGER_VERSION/g" "$APKTOOL_DIR/$f"
    done
fi

if [[ "$SOURCE_SSRM_CONFIG_NAME" != "$TARGET_SSRM_CONFIG_NAME" ]]; then
    echo "Applying SSRM patches"

    DECOMPILE "system/framework/ssrm.jar"

    FTP="
    system/framework/ssrm.jar/smali/com/android/server/ssrm/Feature.smali
    "
    for f in $FTP; do
        sed -i "s/$SOURCE_SSRM_CONFIG_NAME/$TARGET_SSRM_CONFIG_NAME/g" "$APKTOOL_DIR/$f"
    done
fi