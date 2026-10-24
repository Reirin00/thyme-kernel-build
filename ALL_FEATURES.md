# thyme 内核（Mi 10S / 4.19.157）全部可选功能清单

> 目标源码：`Dowsion-dev/mi10s` / `cctv18/kernel_xiaomi_sm8250_mod` / `badelXia/android_kernel_xiaomi_thyme`
> 标注约定：✅ 4.19 原生支持 · 🔧 需要 patch/移植 · ⚠️ 有风险 · ❌ 4.19 不支持

---

## P0 核心推荐（零风险 + 明显收益）

```config
# —— 网络 ——
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y

# —— 文件系统 ——
CONFIG_EROFS_FS=y
CONFIG_EROFS_FS_ZIP=y

# —— 压缩 ——
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y

# —— 内存 ——
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y

# —— 网络安全 ——
CONFIG_IP_SET=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_WIREGUARD=y
```

---

## 一、Root / 隐藏

| 功能 | config | 状态 | 说明 |
|---|---|---|---|
| KernelSU / SukiSU | 🔧 源码集成 | 需 submodule | 不是 config，要 merge 内核代码 |
| SUSFS | 🔧 patch | ⚠️ 4.19 分支需核实 | 隐藏 root/挂载点，主力维护 5.10+ |
| KPROBES | `CONFIG_KPROBES=y` `CONFIG_KPROBE_EVENTS=y` | ✅ | KernelSU 依赖 |
| KALLSYMS_ALL | `CONFIG_KALLSYMS_ALL=y` | ✅ | 符号完整，root 工具依赖 |
| OVERLAY_FS | `CONFIG_OVERLAY_FS=y` | ✅ | Magisk 模块挂载依赖 |
| BINFMT_MISC | `CONFIG_BINFMT_MISC=y` | ✅ | chroot / 容器 |
| 隐藏解锁状态 | 🔧 patch | — | 过滤 `/proc/cmdline` 的 `androidboot.verifiedbootstate` |

---

## 二、网络

### TCP 拥塞控制

| 算法 | config | 状态 |
|---|---|---|
| **BBR** | `CONFIG_TCP_CONG_BBR=y` | ✅ 最推荐 |
| CUBIC（默认） | `CONFIG_TCP_CONG_CUBIC=y` | ✅ |
| Westwood | `CONFIG_TCP_CONG_WESTWOOD=y` | ✅ 弱网红 |
| HTCP | `CONFIG_TCP_CONG_HTCP=y` | ✅ |
| Vegas | `CONFIG_TCP_CONG_VEGAS=y` | ✅ |
| Veno | `CONFIG_TCP_CONG_VENO=y` | ✅ |
| Illinois | `CONFIG_TCP_CONG_ILLINOIS=y` | ✅ |
| DCTCP | `CONFIG_TCP_CONG_DCTCP=y` | ✅ 数据中心 |
| BBRv2 | 🔧 外挂 patch | ⚠️ 停更，不建议 |
| BBRv3 | ❌ | 6.13+ 主线才�� |

### 队列 / 流控

| 功能 | config | 状态 |
|---|---|---|
| **fq**（BBR 必需）| `CONFIG_NET_SCH_FQ=y` | ✅ |
| fq_codel | `CONFIG_NET_SCH_FQ_CODEL=y` | ✅ Android 默认 |
| CAKE | `CONFIG_NET_SCH_CAKE` | 🔧 4.19 需 patch |
| HTB | `CONFIG_NET_SCH_HTB=y` | ✅ 限速 |
| SFB | 🔧 | — |
| TBF | `CONFIG_NET_SCH_TBF=y` | ✅ |

### 其他网络功能

| 功能 | config | 状态 |
|---|---|---|
| IPSet | `CONFIG_IP_SET=y` + `NETFILTER_XT_SET` | ✅ 广告拦截依赖 |
| WireGuard | `CONFIG_WIREGUARD=y` | ✅ 内核级 VPN |
| BPF 分类器 | `CONFIG_NET_CLS_BPF=y` `NET_ACT_BPF=y` | ✅ |
| TCP Fast Open | `CONFIG_TCP_FASTOPEN`（或 sysctl）| ✅ |
| XFRM | `CONFIG_XFRM_USER=y` | ✅ IPsec/VPN |
| MPTCP | 🔧 | 4.19 只有 out-of-tree，5.6+ 主线 |
| netns / veth | `CONFIG_NET_NS=y` `CONFIG_VETH=y` | ✅ 容器 |
| 802.1Q VLAN | `CONFIG_VLAN_8021Q=y` | ✅ |

---

## 三、CPU 调度 / 性能

| 功能 | config / 方式 | 状态 | 备注 |
|---|---|---|---|
| **WALT**（高通调度）| `CONFIG_SCHED_WALT=y` | ✅ thyme 自带 | 别关，高通平台依赖 |
| schedutil | `CONFIG_CPU_FREQ_GOV_SCHEDUTIL=y` | ✅ | EAS 推荐 |
| performance / ondemand / conservative | 对应 config | ✅ | |
| CPU Boost | `CONFIG_CPU_BOOST=y` | ✅ | 触控加速 |
| UClamp | `CONFIG_UCLAMP_TASK=y` `UCLAMP_TASK_GROUP=y` | ✅ | 4.19 已有 |
| **BORE** | 🔧 patch | ⚠️ 4.19 需移植 | 突发优先，界面跟手 |
| PELT 半衰期 | 源码改动 | ⚠️ | 16ms 可降功耗 |
| EAS 能量模型 | `CONFIG_ENERGY_MODEL=y` | ✅ | |
| CPU 超频 | 🔧 dts/opp 表 | ⚠️ 散热差、易锁频 | 不建议 |
| 关闭 SCHED_DEBUG | `# CONFIG_SCHED_DEBUG` | ✅ | 省一点开销 |

---

## 四、内存管理

| 功能 | config | 状态 | 备注 |
|---|---|---|---|
| **ZRAM** | `CONFIG_ZRAM=y` | ✅ | |
| ZRAM zstd | `CONFIG_ZRAM_DEF_COMP_ZSTD=y` | ✅ | 压缩率高 |
| ZRAM lz4 | `CONFIG_ZRAM_DEF_COMP_LZ4=y` | ✅ | 速度快 |
| ZRAM lz4hc / lzo-rle / 842 | 对应 config | ✅ | |
| ZSMALLOC | `CONFIG_ZSMALLOC=y` | ✅ | ZRAM 依赖 |
| ZSTD | `CONFIG_ZSTD_COMPRESS/DECOMPRESS=y` | ✅ | |
| LZ4 / LZO / 842 | `CONFIG_LZ4_*` `CONFIG_LZO_*` `CONFIG_842_*` | ✅ | |
| KSM | `CONFIG_KSM=y` | ✅ | 合并重复页，吃 CPU |
| Frontswap | `CONFIG_FRONTSWAP=y` | ✅ | |
| cgroup memory | `CONFIG_MEMCG=y` | ✅ | |
| **Simple_LMK** | 🔧 patch（Sultan）| ⚠️ | 低压直接杀后台，可能误杀 |
| **Hot-Cold Split** | 🔧 patch | ⚠️ | 热冷页分离 |
| **MGLRU** | `CONFIG_LRU_GEN` | ❌ | 5.15+ 才有 |
| KASAN | `CONFIG_KASAN` | ⚠️ | 性能杀手，只调试用 |
| swap | `CONFIG_SWAP=y` | ✅ | |

---

## 五、存储 / 文件系统

| 功能 | config | 状态 | 备注 |
|---|---|---|---|
| **EROFS** | `CONFIG_EROFS_FS=y` `EROFS_FS_ZIP=y` | ✅ | 只读压缩，快 |
| F2FS | `CONFIG_F2FS_FS=y` | ✅ | `/data` 用 |
| F2FS 压缩 | `CONFIG_F2FS_FS_COMPRESSION=y` | ✅ | |
| F2FS discard | 挂载参数 `discard` 或 `CONFIG_F2FS_...` | ✅ | TRIM |
| EXT4 | `CONFIG_EXT4_FS=y` | ✅ | |
| SQUASHFS | `CONFIG_SQUASHFS=y` + `SQUASHFS_XZ/ZSTD` | ✅ | |
| NTFS3 | `CONFIG_NTFS3_FS` | 🔧 | 主线 5.15，4.19 需 patch |
| NTFS（老，只读）| `CONFIG_NTFS_FS=y` | ✅ | |
| EXFAT | `CONFIG_EXFAT_FS` | 🔧 | 主线 5.7，4.19 需 patch |
| VFAT | `CONFIG_VFAT_FS=y` | ✅ | U 盘 |
| CIFS/SMB | `CONFIG_CIFS=y` | ✅ | 挂 NAS |
| NFS | `CONFIG_NFS_FS=y` | ✅ | |
| FUSE | `CONFIG_FUSE_FS=y` | ✅ | |
| sdcardfs | `CONFIG_SDCARD_FS=y` | ✅ | 老 Android 方案 |
| OverlayFS | `CONFIG_OVERLAY_FS=y` | ✅ | Magisk/容器 |
| UFS Write Booster | 高通 `ufs-qcom` 调参 | 🔧 | 顺序写提升 |

---

## 六、I/O 调度器

| 调度器 | config | 状态 | 适用 |
|---|---|---|---|
| **BFQ** | `CONFIG_IOSCHED_BFQ=y` `CONFIG_MQ_IOSCHED_BFQ=y` | ✅ | 多任务公平 |
| Kyber | `CONFIG_MQ_IOSCHED_KYBER=y` | ✅ | 低延迟 |
| mq-deadline | `CONFIG_MQ_IOSCHED_DEADLINE=y` | ✅ | 默认 |
| **SSG** | 🔧 patch | ⚠️ | UFS 低延迟，牺牲公平 |
| noop / none | 内置 | ✅ | |

---

## 七、安全 / LSM

| 功能 | config | 状态 | 备注 |
|---|---|---|---|
| SELinux | `CONFIG_SECURITY_SELINUX=y` | ✅ | 别关 |
| SELinux permissive 编译期 | `CONFIG_SECURITY_SELINUX_BOOTPARAM_VALUE=1` | ⚠️ | 降低安全性 |
| **BBG** | `CONFIG_BBG=y` | 🔴 | **f2fs NULL deref，见 FEATURES.md** |
| Hardened usercopy | `CONFIG_HARDENED_USERCOPY=y` | ✅ | |
| FORTIFY_SOURCE | `CONFIG_FORTIFY_SOURCE=y` | ✅ | |
| Stack protector | `CONFIG_STACKPROTECTOR_STRONG=y` | ✅ | |
| 随机化 | `CONFIG_RANDOMIZE_BASE=y` | ✅ | KASLR |
| CFI | `CONFIG_CFI_CLANG` | ❌ | 4.19 arm64 不支持 |

---

## 八、容器 / 虚拟化

| 功能 | config | 状态 |
|---|---|---|
| Namespaces | `CONFIG_NAMESPACES=y` + UTS/PID/NET/IPC/USER/UTS | ✅ |
| Cgroups | `CONFIG_CGROUPS=y` + `CGROUP_CPUACCT/DEVICE/FREEZER/SCHED/FREEZER` | ✅ |
| cgroup v2 | `CONFIG_CGROUP_BPF` | ✅ |
| cgroup BPF | `CONFIG_CGROUP_BPF=y` | ✅ |
| veth / bridge | `CONFIG_VETH=y` `CONFIG_BRIDGE=y` | ✅ |
| POSIX MQ | `CONFIG_POSIX_MQUEUE=y` | ✅ |
| KVM | `CONFIG_KVM` | ⚠️ arm64 支持但耗性能 |

---

## 九、硬件支持

### USB

| 功能 | config | 状态 |
|---|---|---|
| CH341 | `CONFIG_USB_SERIAL_CH341=y` | ✅ |
| CH343 | 🔧 需新驱动 | — |
| FTDI | `CONFIG_USB_SERIAL_FTDI_SIO=y` | ✅ |
| PL2303 | `CONFIG_USB_SERIAL_PL2303=y` | ✅ |
| CP210X | `CONFIG_USB_SERIAL_CP210X=y` | ✅ |
| QTI/SPCP8X5 | `CONFIG_USB_SERIAL_...` | ✅ |
| USB Gadget | `CONFIG_USB_CONFIGFS=y` + function 子项 | ✅ |
| USB 网卡 | `CONFIG_USB_USBNET=y` + `R8152`（2.5G）| ✅ |

### 其他外设

| 功能 | config | 状态 |
|---|---|---|
| CAN / USB-CAN | `CONFIG_CAN=y` `CONFIG_CAN_RAW=y` + driver | 🔧 driver 需加 |
| 手柄（Xbox）| `CONFIG_JOYSTICK_XPAD=y` | ✅ |
| HID 通用 | `CONFIG_HID_GENERIC=y` + 子项 | ✅ |
| UINPUT（模拟输入）| `CONFIG_INPUT_UINPUT=y` | ✅ 自动化测试 |
| 蓝牙 HID | `CONFIG_BT_HIDP=y` | ✅ |

---

## 十、调试 / 取证

| 功能 | config | 状态 | 备注 |
|---|---|---|---|
| KALLSYMS_ALL | `CONFIG_KALLSYMS_ALL=y` | ✅ | 已开 |
| PSTORE | `CONFIG_PSTORE=y` `PSTORE_RAM=y` `PSTORE_CONSOLE=y` | ✅ | 上次 panic 日志 |
| MAGIC_SYSRQ | `CONFIG_MAGIC_SYSRQ=y` | ✅ | 应急 |
| FTRACE | `CONFIG_FTRACE=y` `FUNCTION_TRACER=y` | ✅ | 性能分析 |
| PERF_EVENTS | `CONFIG_PERF_EVENTS=y` | ✅ | 已开 |
| BPF JIT | `CONFIG_BPF_JIT=y` | ✅ | |
| KGDB | `CONFIG_KGDB` | ⚠️ | 需串口调试 |
| DEBUG_INFO | `CONFIG_DEBUG_INFO=y` | ⚠️ | 体积 +几 GB |
| KASAN | `CONFIG_KASAN` | ⚠️ | 性能 -50%+ |

---

## 十一、编译优化

| 选项 | config | 状态 | 备注 |
|---|---|---|---|
| -O2 | `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y` | ✅ | 默认 |
| -O3 | 手动改 Makefile | ⚠️ | 可能反向优化 |
| LTO_CLANG | `CONFIG_LTO_CLANG` | ⚠️ | 4.19 + clang 10 易炸 |
| ThinLTO | ❌ | 需 clang 12+ |
| ARMv8.2 指令 | `-march=armv8.2-a` | ✅ | 需确认 SoC 支持 |
| 关闭 DEBUG 选项 | 大量 `# CONFIG_..._DEBUG` | ✅ | 体积/性能 |

---

## 十二、电源管理

| 功能 | config | 状态 |
|---|---|---|
| Suspend | `CONFIG_SUSPEND=y` | ✅ |
| Autosleep | `CONFIG_PM_AUTOSLEEP=y` | ✅ |
| CPU Idle | `CONFIG_CPU_IDLE=y` + governor | ✅ |
| 省电 WQ | `CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y` | ✅ |
| 关闭 debug 唤醒源 | `# CONFIG_PM_DEBUG` | ✅ |

---

## 十三、黑名单（别碰）

| 项 | 原因 |
|---|---|
| **BBG** | f2fs rename → NULL deref → 随机 panic |
| **MGLRU** | 4.19 无此功能 |
| **BBRv2** | 补丁停更，4.19 行为不可预期 |
| **CFI_CLANG** | 4.19 arm64 不支持 |
| **KASAN** | 性能腰斩，只适合调试 |
| **超频** | thyme 散热差，容易锁频/降频 |
| **重编 dtbo** | 锁屏闪最高亮度 / 手势失效 / 卡槽无信号 |
| **LTO** | 4.19 + clang 10 组合容易链接失败 |
| **关 SELinux** | 系统起不来（Android 强依赖）|

---

## 十四、三套推荐组合

### A. 稳妥日常（推荐）

```config
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_EROFS_FS=y
CONFIG_EROFS_FS_ZIP=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_IP_SET=y
CONFIG_NETFILTER_XT_SET=y
CONFIG_WIREGUARD=y
CONFIG_MQ_IOSCHED_KYBER=y
```
风险：零。收益：网络、存储、内存全面提升。

### B. 加 root 隐藏

在 A 基础上加：

```
KernelSU / SukiSU（源码集成）
SUSFS（patch，先核实 4.19 分支）
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y
CONFIG_KALLSYMS_ALL=y
```

风险：中（SUSFS 4.19 完整性未知）。

### C. 折腾型（嵌入式/容器）

在 A 基础上加：

```
CONFIG_USB_SERIAL_CH341=y
CONFIG_USB_SERIAL_FTDI_SIO=y
CONFIG_USB_SERIAL_PL2303=y
CONFIG_USB_SERIAL_CP210X=y
CONFIG_CAN=y
CONFIG_CAN_RAW=y
CONFIG_NAMESPACES=y
CONFIG_CGROUPS=y
CONFIG_VETH=y
CONFIG_BRIDGE=y
CONFIG_POSIX_MQUEUE=y
```
风险：低，但占内存。

---

## 十五、thyme 专属注意

1. **「电量卡 1%」bug**：PM8150 GEN4 电量计，必须用 `yspbwx2010` 修复过的分支
2. **dtbo 别刷**：编译产物里的 dtbo.img 会导致锁屏闪最高亮度、手势失效、卡槽无信号
3. **BL 已解锁**：刷内核不会触发 AVB，但写错分区仍需 9008 救
4. **debugfs 关闭**：`# CONFIG_DEBUG_FS` 可省一点内存，但会丢调试能力

---

## 十六、编译验证清单（刷完自查）

```bash
# 网络
cat /proc/sys/net/ipv4/tcp_available_congestion_control   # 应含 bbr
cat /proc/sys/net/ipv4/tcp_congestion_control             # 应显示 bbr
tc qdisc show | grep fq

# 文件系统
cat /proc/filesystems | grep erofs
cat /proc/filesystems | grep f2fs

# 内存
cat /proc/meminfo | grep -i zram
cat /sys/block/zram0/comp_algorithm                       # 应含 zstd

# root（如果集成）
which su; id

# 内核功能
zcat /proc/config.gz | grep CONFIG_TCP_CONG_BBR           # 若开了 IKCONFIG
```
