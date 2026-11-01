### AnyKernel3 Ramdisk Mod Script
properties() { '
kernel.string=thyme-kernel by WorkBuddy
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=thyme
device.name2=Mi 10S
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

# 直接写 boot_a：thyme 的 TWRP 里 bootctl 是坏的（Error getting bootctrl v1.2 module），
# IS_SLOT_DEVICE=1 会让 AK3 在 get_slot 处失败中止
BLOCK=/dev/block/bootdevice/by-name/boot_a;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=0;

. tools/ak3-core.sh;

dump_boot;
write_boot;
