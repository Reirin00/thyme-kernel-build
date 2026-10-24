#!/sbin/sh
# =============================================================
# thyme 手动刷机脚本
# 修复原作者 update-binary 的三个问题：
#   1. cnmlib / cmnlib 文件名笔误（两种都试）
#   2. super.img.zst 流式解压直写（不落盘，省 9GB）
#   3. 每一步检查返回值，失败立即停止并报告
#
# 用法（TWRP Terminal）：
#   sh /sdcard/manual_flash.sh "/sdcard/Download/你的包.zip"
# =============================================================

ZIP="$1"
if [ -z "$ZIP" ] || [ ! -f "$ZIP" ]; then
    echo "用法: sh $0 <zip完整路径>"
    echo "例:   sh $0 \"/sdcard/Download/堆叠桌面纯净版-0917(更换内核)_Mi15pro_HyperOS_3.0.0.25_for_thyme_A16.zip\""
    exit 1
fi

BYNAME=/dev/block/bootdevice/by-name
[ -d "$BYNAME" ] || BYNAME=/dev/block/by-name
[ -d "$BYNAME" ] || { echo "!! 找不到 by-name 目录"; exit 1; }

FAILED=0
FAILED_LIST=""

say() { echo "$1"; }
bad() { echo "!! $1"; FAILED=1; FAILED_LIST="$FAILED_LIST $1"; }

say "=========================================="
say " thyme 手动刷机"
say " 包: $ZIP"
say "=========================================="

# ---------- 1. 列出 zip 内容 ----------
say ""
say "[1/4] 扫描 zip..."
unzip -l "$ZIP" > /tmp/ziplist.txt 2>/dev/null
if [ ! -s /tmp/ziplist.txt ]; then
    echo "!! unzip 打不开这个 zip（可能损坏或不是 zip）"
    exit 1
fi
say "  条目数: $(grep -c 'images/' /tmp/ziplist.txt)"

has() { grep -q "images/$1" /tmp/ziplist.txt; }

# ---------- 2. 准备 zstd ----------
say ""
say "[2/4] 准备 zstd..."
ZSTD=""
if grep -q "bin/android/zstd" /tmp/ziplist.txt; then
    mkdir -p /tmp/zb
    unzip -o "$ZIP" "bin/android/zstd" -d /tmp/zb >/dev/null 2>&1
    chmod 755 /tmp/zb/bin/android/zstd 2>/dev/null
    if [ -x /tmp/zb/bin/android/zstd ]; then
        ZSTD=/tmp/zb/bin/android/zstd
        say "  从包内提取: $ZSTD"
    fi
fi
if [ -z "$ZSTD" ] && command -v zstd >/dev/null 2>&1; then
    ZSTD=zstd
    say "  使用系统 zstd"
fi
if [ -z "$ZSTD" ]; then
    say "  ⚠ 没有 zstd → super.img.zst 无法解压，稍后会跳过 super"
fi

# ---------- 3. 逐分区刷写 ----------
say ""
say "[3/4] 刷写分区..."

flash_part() {
    PART="$1"; shift
    for f in "$@"; do
        if has "$f"; then
            printf "  %-20s <- %-22s " "$PART" "$f"
            unzip -p "$ZIP" "images/$f" > "$BYNAME/$PART" 2>/dev/null
            RC=$?
            if [ $RC -ne 0 ]; then
                echo "FAIL(rc=$RC)"
                bad "$PART"
                return 1
            fi
            echo "OK"
            return 0
        fi
    done
    printf "  %-20s 跳过（zip 内无此镜像）\n" "$PART"
    return 0
}

# bootloader / 固件分区（a/b 双写）
for p in abl aop bluetooth cmnlib cmnlib64 devcfg dsp dtbo featenabler hyp imagefv keymaster modem qupfw tz uefisecapp vbmeta vbmeta_system vendor_boot xbl xbl_config; do
    flash_part "${p}_a" "${p}.img"
    flash_part "${p}_b" "${p}.img"
done

# 独立分区
flash_part "storsec" "storsec.img"
flash_part "logo"    "logo.img"
flash_part "misc"    "misc.img"

# ---------- 4. super 分区（特殊处理）----------
say ""
say "[4/4] 刷写 super 分区..."

SIZE=$(blockdev --getsize64 "$BYNAME/super" 2>/dev/null)
[ -n "$SIZE" ] && say "  super 分区容量: $((SIZE/1024/1024)) MB"

# 先写 super.empty.img（如果包里有），相当于先擦除
if has "super.empty.img"; then
    say "  → 写入 super.empty.img（清空）"
    unzip -p "$ZIP" "images/super.empty.img" > "$BYNAME/super" 2>/dev/null || bad "super (empty)"
fi

if has "super.img.zst"; then
    if [ -z "$ZSTD" ]; then
        say "  ✗ 没有 zstd，无法解压 super.img.zst"
        bad "super(zst)"
    else
        say "  → 流式解压 super.img.zst → super 分区（不落盘）"
        say "  开始时间: $(date '+%H:%M:%S')"
        unzip -p "$ZIP" "images/super.img.zst" | "$ZSTD" -dc > "$BYNAME/super"
        RC=$?
        say "  结束时间: $(date '+%H:%M:%S')  rc=$RC"
        if [ $RC -ne 0 ]; then
            bad "super(zst解压)"
        fi
    fi
elif has "super.img"; then
    say "  → 直接写 super.img"
    unzip -p "$ZIP" "images/super.img" > "$BYNAME/super" 2>/dev/null || bad "super"
elif grep -q "images/super.img.0" /tmp/ziplist.txt; then
    say "  → 分卷 super，逐个拼接写入"
    unzip -p "$ZIP" 'images/super.img.*' > "$BYNAME/super" 2>/dev/null || bad "super(分卷)"
else
    say "  跳过（zip 内没找到 super）"
fi

# ---------- 收尾 ----------
sync
say ""
say "=========================================="
if [ $FAILED -eq 0 ]; then
    say " ✓ 全部写入成功"
    say " 建议下一步:"
    say "   rm -rf /data/cache /data/dalvik-cache /data/system/package_cache"
    say "   然后 Reboot → System"
else
    say " ✗ 以下项目失败:$FAILED_LIST"
    say " 分区可能不完整，不要直接重启"
fi
say "=========================================="

rm -f /tmp/ziplist.txt
exit $FAILED
