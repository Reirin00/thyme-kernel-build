#!/system/bin/sh
# =============================================================
# thyme (小米 10S / SM8250) 内核运行时调优
# 用法: su -c 'sh /data/local/tmp/thyme_tune.sh'
# 或放进 Magisk 模块的 post-fs-data.sh
#
# 针对：4.19.157-perf + BBR + UClamp + ZRAM(LZ4)
# =============================================================

LOG=/data/local/tmp/thyme_tune.log
exec >> "$LOG" 2>&1
echo ""
echo "===== $(date) ====="

wait_boot() {
    i=0
    while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 120 ]; do
        sleep 1; i=$((i+1))
    done
    sleep 8
}
[ "$1" = "--no-wait" ] || wait_boot

ok()  { echo "  [OK]   $1"; }
skip(){ echo "  [SKIP] $1"; }

# ==========================================================
# 1. UClamp 激活（性能与省电的核心）
# ==========================================================
# 值域 0~1024（对应 0~100%）。102 ≈ 10%，200 ≈ 20%
echo "--- UClamp ---"
UCLAMP_SET() {
    local g="$1" max="$2" min="$3"
    local base="/dev/cpuctl/$g"
    [ -d "$base" ] || { skip "$g (不存在)"; return; }
    [ -w "$base/cpu.uclamp.max" ] && echo "$max" > "$base/cpu.uclamp.max"
    [ -w "$base/cpu.uclamp.min" ] && echo "$min" > "$base/cpu.uclamp.min"
    ok "$g  max=$max min=$min"
}
UCLAMP_SET top-app            1024 102
UCLAMP_SET foreground         1024 0
UCLAMP_SET background          200 0
UCLAMP_SET system-background   400 0

# latency_sensitive 是 5.4+ 才有的 cgroup 属性，4.19 上通常不存在
for g in top-app foreground background system-background; do
    f="/dev/cpuctl/$g/cpu.uclamp.latency_sensitive"
    if [ -w "$f" ]; then echo 1 > "$f"; ok "$g latency_sensitive=1"; fi
done

# ==========================================================
# 2. schedutil 调频速率
# ==========================================================
# 注意：4.19 只有 rate_limit_us 一个参数（up/down 分离是 5.4+）
# 值越小越灵敏（更费电），越大越省电（可能掉帧）
echo "--- schedutil ---"
for p in /sys/devices/system/cpu/cpufreq/policy*; do
    [ -w "$p/schedutil/rate_limit_us" ] || continue
    idx=$(basename "$p" | sed 's/policy//')
    case "$idx" in
        7) echo 4000 > "$p/schedutil/rate_limit_us" ;;   # 超大核：迟钝一点，防误升频
        4) echo 2000 > "$p/schedutil/rate_limit_us" ;;   # 中核
        *) echo 3000 > "$p/schedutil/rate_limit_us" ;;   # 小核：更省电
    esac
    ok "policy$idx rate_limit_us=$(cat "$p/schedutil/rate_limit_us")"
done

# ==========================================================
# 3. ZRAM（LZ4 + 6GB）
# ==========================================================
# LZ4 压缩/解压快 → 换页 CPU 开销低 → 更省电
# 6GB 弥补 LZ4 压缩率低于 ZSTD 的劣势
echo "--- ZRAM ---"
swapoff /dev/block/zram0 2>/dev/null
echo 1 > /sys/block/zram0/reset 2>/dev/null
sleep 1
# 顺序很重要：reset → comp_algorithm → disksize → mkswap → swapon
if [ -w /sys/block/zram0/comp_algorithm ]; then
    echo lz4 > /sys/block/zram0/comp_algorithm && ok "comp_algorithm=lz4"
fi
if [ -w /sys/block/zram0/disksize ]; then
    echo 6442450944 > /sys/block/zram0/disksize && ok "disksize=6GB"
    mkswap /dev/block/zram0 >/dev/null 2>&1 && swapon /dev/block/zram0 && ok "swapon OK"
fi

# ==========================================================
# 4. 内存 sysctl
# ==========================================================
echo "--- vm ---"
# Android 上 swappiness=100 是对的：多用 ZRAM（内存盘，快），少杀进程
echo 100 > /proc/sys/vm/swappiness && ok "swappiness=100"
echo 50  > /proc/sys/vm/vfs_cache_pressure && ok "vfs_cache_pressure=50"
echo 10  > /proc/sys/vm/dirty_ratio && ok "dirty_ratio=10"
echo 5   > /proc/sys/vm/dirty_background_ratio && ok "dirty_bg_ratio=5"
echo 0   > /proc/sys/vm/page-cluster && ok "page-cluster=0"

# KSM 默认关闭（本次内核 KSM 已强制 not-set）
[ -w /sys/kernel/mm/ksm/run ] && echo 0 > /sys/kernel/mm/ksm/run && ok "KSM off"

# ==========================================================
# 5. I/O（Kyber + 预读）
# ==========================================================
echo "--- I/O ---"
for dev in /sys/block/sd*; do
    [ -w "$dev/queue/scheduler" ] && echo kyber > "$dev/queue/scheduler" && ok "$(basename $dev) scheduler=kyber"
    [ -w "$dev/queue/read_ahead_kb" ] && echo 512 > "$dev/queue/read_ahead_kb"
    [ -w "$dev/queue/nr_requests" ] && echo 256 > "$dev/queue/nr_requests"
    [ -w "$dev/queue/iostats" ] && echo 0 > "$dev/queue/iostats"
    [ -w "$dev/queue/add_random" ] && echo 0 > "$dev/queue/add_random"
done

# ==========================================================
# 6. 网络（BBR + fq）
# ==========================================================
echo "--- net ---"
echo bbr > /proc/sys/net/ipv4/tcp_congestion_control && ok "tcp_congestion_control=bbr"
echo 3 > /proc/sys/net/ipv4/tcp_fastopen && ok "tcp_fastopen=3"
# default_qdisc 改成 fq：BBR 需要，但只影响新建的网卡队列
[ -w /proc/sys/net/core/default_qdisc ] && echo fq > /proc/sys/net/core/default_qdisc && ok "default_qdisc=fq"
# 收发缓冲加大
echo 262144 > /proc/sys/net/core/rmem_max 2>/dev/null
echo 262144 > /proc/sys/net/core/wmem_max 2>/dev/null

# ==========================================================
# 7. 运行时关掉内核调试开销（不改 config，不动符号）
# ==========================================================
echo "--- debug off ---"
echo 0 > /proc/sys/kernel/sched_schedstats 2>/dev/null && ok "sched_schedstats=0"
[ -w /proc/sys/kernel/printk_devkmsg ] && echo "off" > /proc/sys/kernel/printk_devkmsg && ok "printk_devkmsg=off"

# ==========================================================
# 8. cpuset 绑核（Android 默认已配，这里只做兜底）
# ==========================================================
echo "--- cpuset ---"
# SM8250: 0-3 = A55 小核, 4-6 = A77 中核, 7 = A77 超大核
[ -w /dev/cpuset/background/cpus ] && echo "0-3" > /dev/cpuset/background/cpus && ok "background=0-3"
[ -w /dev/cpuset/system-background/cpus ] && echo "0-3" > /dev/cpuset/system-background/cpus
[ -w /dev/cpuset/foreground/cpus ] && echo "0-6" > /dev/cpuset/foreground/cpus
[ -w /dev/cpuset/top-app/cpus ] && echo "0-7" > /dev/cpuset/top-app/cpus

echo "===== done ====="
