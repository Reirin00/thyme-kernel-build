# thyme defconfig 功能全表（基于真实文件核对）

> 数据源：`arch/arm64/configs/thyme_defconfig`（`cctv18/kernel_xiaomi_sm8250_mod` 分支 `android14-lineage22-mod`）
> 795 行 / 769 个 `CONFIG_` 条目

## 图例

| 标记 | 含义 |
|---|---|
| **Y** | defconfig 里显式 `=y`，**已开** |
| **n** | Kconfig 默认 `n`，**未提就必须显式加** |
| **y\*** | Kconfig 默认 `y`，未提=**已开** |
| **✗** | 4.19 内核里**不存在这个选项** |

---

## 一、网络

| 功能 | config | 状态 |
|---|---|---|
| BBR 父菜单 | `TCP_CONG_ADVANCED` | **n** ← 不加这行，BBR 那行会被静默忽略 |
| **BBR** | `TCP_CONG_BBR` | **n** |
| 默认算法 | `DEFAULT_TCP_CONG` | **n**（默认 cubic）|
| CUBIC | `TCP_CONG_CUBIC` | y*（ADVANCED 关闭时走内置）|
| Westwood | `TCP_CONG_WESTWOOD` | **n** |
| HTCP | `TCP_CONG_HTCP` | **n** |
| VEGAS | `TCP_CONG_VEGAS` | **n** |
| VENO | `TCP_CONG_VENO` | **n** |
| Illinois | `TCP_CONG_ILLINOIS` | **n** |
| DCTCP | `TCP_CONG_DCTCP` | **n** |
| **fq 队列** | `NET_SCH_FQ` | **n** ← BBR 必须配 |
| fq_codel | `NET_SCH_FQ_CODEL` | **n** |
| CAKE | `NET_SCH_CAKE` | **n**（需 patch 支持）|
| HTB | `NET_SCH_HTB` | **Y** |
| SFB | `NET_SCH_SFB` | **n** |
| TBF | `NET_SCH_TBF` | **n** |
| **IPSet** | `IP_SET` | **n** |
| IPSet 匹配 | `NETFILTER_XT_SET` | **n** |
| WireGuard | `WIREGUARD` | **Y** |
| BPF | `BPF_SYSCALL` / `BPF_JIT` | **Y** / **Y** |
| BPF 分类器 | `NET_CLS_BPF` | **Y** |
| XFRM（IPsec/VPN）| `XFRM_USER` | **Y** |
| 网络命名空间 | `NET_NS` | y* |
| veth / bridge | `VETH` / `BRIDGE` | **Y** / **Y** |
| MPTCP | `MPTCP` | ✗（5.6+ 主线）|

## 二、内存

| 功能 | config | 状态 |
|---|---|---|
| ZRAM | `ZRAM` | **Y** |
| ZRAM writeback | `ZRAM_WRITEBACK` | **Y** |
| ZRAM 压缩算法 | `ZRAM_DEF_COMP_*` | 未指定（choice，默认 LZO-RLE）|
| ZSMALLOC | `ZSMALLOC` | **Y** |
| **ZSTD 压缩** | `ZSTD_COMPRESS` / `ZSTD_DECOMPRESS` | **n** |
| LZ4 | `LZ4_COMPRESS` | y*（有 `CRYPTO_LZ4=y`）|
| LZO | `LZO_COMPRESS` | y* |
| 842 | `842_COMPRESS` | **n** |
| **KSM** | `KSM` | **n** |
| Frontswap | `FRONTSWAP` | **n** |
| SWAP | `SWAP` | y* |
| memcg | `MEMCG` | **Y** |
| MGLRU | `LRU_GEN` | ✗（5.15+）|

## 三、存储 / 文件系统

| 功能 | config | 状态 |
|---|---|---|
| EROFS | `EROFS_FS` | **Y** |
| F2FS | `F2FS_FS` | **Y** |
| F2FS 压缩 | `F2FS_FS_COMPRESSION` | **Y** |
| EXT4 | `EXT4_FS` | **Y** |
| EXFAT | `EXFAT_FS` | **Y** |
| VFAT | `VFAT_FS` | **Y** |
| FUSE | `FUSE_FS` | **Y** |
| OverlayFS | `OVERLAY_FS` | **Y** |
| sdcardfs | `SDCARD_FS` | **Y** |
| BFQ | `IOSCHED_BFQ` | **Y** |
| **Kyber** | `MQ_IOSCHED_KYBER` | **n** |
| mq-deadline | `MQ_IOSCHED_DEADLINE` | y* |
| SQUASHFS | `SQUASHFS` | **n** |
| CIFS/SMB | `CIFS` | **n** |
| NFS | `NFS_FS` | y* |
| NTFS（只读）| `NTFS_FS` | **n** |
| NTFS3（读写）| `NTFS3_FS` | ✗（5.15+）|
| SSG 调度器 | — | ✗（需 patch）|

## 四、安全

| 功能 | config | 状态 |
|---|---|---|
| SELinux | `SECURITY_SELINUX` | **Y** |
| Hardened usercopy | `HARDENED_USERCOPY` | **Y** |
| FORTIFY_SOURCE | `FORTIFY_SOURCE` | y* |
| Stack protector | `STACKPROTECTOR_STRONG` | y* |
| KASLR | `RANDOMIZE_BASE` | **Y** |
| KALLSYMS_ALL | `KALLSYMS_ALL` | **Y** |
| 模块签名 | `MODULE_SIG` | **Y** |
| **KPROBES** | `KPROBES` | **n** ← KernelSU 必需 |
| **KPROBE_EVENTS** | `KPROBE_EVENTS` | **n** ← KernelSU 必需 |
| BBG | `BBG` | ✗（**源码树里没有 baseband_guard 目录**）|
| CFI | `CFI_CLANG` | ✗（4.19 arm64 不支持）|

## 五、CPU 调度

| 功能 | config | 状态 |
|---|---|---|
| WALT | `SCHED_WALT` | **Y**（高通调度，别关）|
| EAS 能量模型 | `ENERGY_MODEL` | **Y** |
| CPU Boost | `CPU_BOOST` | **Y** |
| schedutil | `CPU_FREQ_GOV_SCHEDUTIL` | **Y** |
| ondemand | `CPU_FREQ_GOV_ONDEMAND` | **Y** |
| conservative | `CPU_FREQ_GOV_CONSERVATIVE` | **Y** |
| performance | `CPU_FREQ_GOV_PERFORMANCE` | y* |
| **UClamp** | `UCLAMP_TASK` | **n** |
| **UClamp 分组** | `UCLAMP_TASK_GROUP` | **n** |
| BORE | — | ✗（需 patch）|
| PELT 半衰期 | — | 需改源码 |

## 六、硬件支持

| 功能 | config | 状态 |
|---|---|---|
| CH341 | `USB_SERIAL_CH341` | **Y** |
| FTDI | `USB_SERIAL_FTDI_SIO` | **Y** |
| PL2303 | `USB_SERIAL_PL2303` | **Y** |
| CP210X | `USB_SERIAL_CP210X` | **Y** |
| USB Gadget | `USB_CONFIGFS` | **Y** |
| RTL8152（USB 网卡）| `USB_RTL8152` | **Y** |
| CAN | `CAN` | **Y** |
| CAN_RAW | `CAN_RAW` | y*（if CAN）|
| Xbox 手柄 | `JOYSTICK_XPAD` | **Y** |
| UINPUT | `INPUT_UINPUT` | **Y** |
| HID 通用 | `HID_GENERIC` | y* |
| 蓝牙 HID | `BT_HIDP` | y* |

## 七、调试 / 取证

| 功能 | config | 状态 |
|---|---|---|
| IKCONFIG | `IKCONFIG` / `IKCONFIG_PROC` | **Y** / **Y**（可读 `/proc/config.gz`）|
| MAGIC_SYSRQ | `MAGIC_SYSRQ` | **Y** |
| PSTORE | `PSTORE` | **Y** |
| PSTORE_RAM | `PSTORE_RAM` | **Y** |
| PSTORE_CONSOLE | `PSTORE_CONSOLE` | **Y**（上次 panic 日志）|
| debugfs | `DEBUG_FS` | y* |
| perf | `PERF_EVENTS` | y* |
| ftrace | `FTRACE` | y* |
| function tracer | `FUNCTION_TRACER` | **n** |
| KASAN | `KASAN` | **n**（别开，性能腰斩）|
| KGDB | `KGDB` | **n** |

## 八、容器 / 电源 / 编译

| 功能 | config | 状态 |
|---|---|---|
| Namespaces | `NAMESPACES` | **Y** |
| Cgroups | `CGROUPS` | y* |
| cgroup BPF | `CGROUP_BPF` | **Y** |
| POSIX MQ | `POSIX_MQUEUE` | y* |
| Suspend | `SUSPEND` | y* |
| CPU Idle | `CPU_IDLE` | **Y** |
| Autosleep | `PM_AUTOSLEEP` | **n** |
| 省电 WQ | `WQ_POWER_EFFICIENT_DEFAULT` | **n** |
| -O2 | `CC_OPTIMIZE_FOR_PERFORMANCE` | y* |
| LTO | `LTO_CLANG` | 4.19 存在但实验性；clang 10 + 4.19 开 LTO 链接易失败，不建议 |

---

## 九、要加的话，加这些（按性价比）

### 第一批：确定要加（workflow 已包含）

```config
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y
CONFIG_IP_SET=y
CONFIG_IP_SET_MAX=256
CONFIG_NETFILTER_XT_SET=y
CONFIG_KSM=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_ZSTD=y
CONFIG_MQ_IOSCHED_KYBER=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_CIFS=y
```

### 第二批：可选

```config
CONFIG_TCP_CONG_WESTWOOD=y      # 备选算法
CONFIG_TCP_CONG_HTCP=y
CONFIG_TCP_CONG_VEGAS=y
CONFIG_UCLAMP_TASK=y            # 日常流畅度
CONFIG_UCLAMP_TASK_GROUP=y
CONFIG_KPROBES=y                # 只在装 KernelSU 时需要
CONFIG_KPROBE_EVENTS=y
```

### 第三批：别碰

```config
CONFIG_BBG            ✗ 源码树里没有
CONFIG_MGLRU          ✗ 不存在
CONFIG_NTFS3_FS       ✗ 不存在
CONFIG_LTO_CLANG      ✗ 不存在
CONFIG_CFI_CLANG      ✗ 不存在
CONFIG_KASAN          ✗ 性能腰斩
```
