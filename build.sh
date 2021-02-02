#!/bin/bash

# IceKernel CI | Powered by Drone | 2020 -

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
prebuilt/mkbootimg \
    --kernel arch/arm64/boot/Image.gz \
    --ramdisk prebuilt/ramdisk.gz \
    --cmdline 'androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user' \
    --base           0x00000000 \
    --pagesize       4096 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00000000 \
    --tags_offset    0x00000100 \
    --dtb            ./dtb \
    --dtb_offset     0x01f00000 \
    --os_version     '11.0.0' \
    --os_patch_level '2020-12' \
    --header_version 2 \
    -o $VERSION.img

magiskboot=prebuilt/magiskboot
magiskinit=prebuilt/magiskinit

# Force kernel to load rootfs
# skip_initramfs -> want_initramfs
$magiskboot \
    --decompress arch/arm64/boot/Image.gz arch/arm64/boot/Image
$magiskboot \
    --hexpatch arch/arm64/boot/Image \
    736B69705F696E697472616D667300 \
    77616E745F696E697472616D667300
$magiskboot \
    --compress=gzip arch/arm64/boot/Image arch/arm64/boot/new_Image.gz

# Unpack
$magiskboot unpack $VERSION.img
gzip -d prebuilt/ramdisk.gz

# Patch ramdisk
echo
echo "Patching ramdisk"
echo
echo "KEEPVERITY=false" > config
echo "KEEPFORCEENCRYPT=false" >> config

$magiskboot cpio prebuilt/ramdisk \
    "add 750 init $magiskinit" \
    "patch" \
    "backup ramdisk.cpio.orig" \
    "mkdir 000 .backup" \
    "add 000 .backup/.magisk config"

gzip prebuilt/ramdisk

echo
echo "Building Patched Kernel Image"
echo
find arch/arm64/boot/dts/qcom -name '*.dtb' -exec cat {} + > ./dtb
prebuilt/mkbootimg \
    --kernel arch/arm64/boot/new_Image.gz \
    --ramdisk prebuilt/ramdisk.gz \
    --cmdline 'androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=2048 loop.max_part=7 androidboot.usbcontroller=a600000.dwc3 buildvariant=user' \
    --base           0x00000000 \
    --pagesize       4096 \
    --kernel_offset  0x00008000 \
    --ramdisk_offset 0x01000000 \
    --second_offset  0x00000000 \
    --tags_offset    0x00000100 \
    --dtb            ./dtb \
    --dtb_offset     0x01f00000 \
    --os_version     '11.0.0' \
    --os_patch_level '2020-12' \
    --header_version 2 \
    -o ${VERSION}_patched.img

rm -rf ramdisk.cpio ramdisk.cpio.orig config

if [[ "${1}" == "upload" ]]; then
	echo
	echo "Uploading"
	echo
    md5sum $VERSION.img
    md5sum ${VERSION}_patched.img
    echo
	curl -sL https://git.io/file-transfer | sh
	./transfer wet $VERSION.img
	./transfer wet ${VERSION}_patched.img
fi
