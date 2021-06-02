#!/bin/bash

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-none-eabi-
export KJOBS="$((`grep -c '^processor' /proc/cpuinfo` * 2))"
VERSION="$(cat arch/arm64/configs/sm8150-perf_defconfig | grep "CONFIG_LOCALVERSION\=" | sed -r 's/.*"(.+)".*/\1/' | sed 's/^.//')"

echo
echo "Setting defconfig"
echo
make sm8150-perf_defconfig || exit 1

echo
echo "Compiling"
echo 
make -j${KJOBS} || exit 1

echo
echo "Building Kernel Image"
echo
find arch/arm64/boot/dts/qcom -name '*.dtb' -exec cat {} + > ./dtb
prebuilts/mkbootimg \
    --kernel arch/arm64/boot/Image.gz \
    --ramdisk prebuilts/ramdisk.gz \
    --cmdline 'androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 firmware_class.path=/vendor/firmware_mnt/image loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 skip_override androidboot.fastboot=1 buildvariant=eng androidboot.selinux=permissive' \
    --base           0x00000000 \
    --pagesize       4096 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00000000 \
    --tags_offset    0x00000100 \
    --dtb            ./dtb \
    --dtb_offset     0x01f00000 \
    --os_version     '16.1.0' \
    --os_patch_level '2099-12' \
    --header_version 2 \
    -o $VERSION.img

if [[ "${1}" == "upload" ]]; then
    echo
    echo "Uploading"
    echo
    md5sum $VERSION.img
    echo
    curl -sL https://git.io/file-transfer | bash -s beta
    ./transfer wet $VERSION.img
fi
