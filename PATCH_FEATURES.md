# 需要 patch / 源码改动的功能（thyme 4.19）

> 区分「只需 config」和「真需要 patch」。
> 生成：2026-10-25

---

## ⚠️ 先纠正一个常见误解

**CAKE 队列不需要 patch。**

`net/sched/sch_cake.c` 在 Linux 4.19 主线就存在（3.19 引入），
只是 `cvt18/kernel_xiaomi_sm8250_mod` 的 defconfig 没开。

```config
CONFIG_NET_SCH_CAKE=y     ← 加这一行就行，不需要 patch
```

同理，下面这些也是「只需 config」，不在此文范围：
`FQ_CODEL` / `SFB` / `TBF` / `VENO` / `ILLINOIS` / `DCTCP` / `842_COMPRESS` / `NTFS_FS`

---

## 一、有现成 patch 的（社区做过）

### 1. SSG I/O 调度器 — 推荐度 ⭐⭐⭐

| | |
|---|---|
| 是什么 | 针对 UFS / NVMe 的单队列低延迟 I/O 调度器 |
| 原理 | 只维护同步/异步两个队列，异步有延迟上限，避免写操作堵塞读 |
| 收益 | App 启动、装包、开相册更快；代价是大文件传输不如 BFQ 公平 |
| 难度 | **低** — 加一个 `.c` 文件 + Kconfig + Makefile 三处 |
| 风险 | **低** — 独立调度器，不影响其他子系统 |
| 来源 | `github.com/tytydraco/SSG`（需确认支持 4.19，分支可能叫 `4.19` 或 `legacy`）|
| 实施 | 复制 `ssg-iosched.c` 到 `block/`，改 `block/Kconfig.iosched` 和 `block/Makefile`，defconfig 加 `CONFIG_IOSCHED_SSG=y` |

**这是所有 patch 里性价比最高的。**

### 2. Simple_LMK — 推荐度 ⭐⭐

| | |
|---|---|
| 是什么 | 内存压力时直接杀后台进程（替代 lmkd 的用户空间判断）|
| 原理 | 遍历 LRU 尾部，按 oom_score 杀，只保留最少的 |
| 收益 | 低内存时不卡顿（避免 lmkd 反应慢导致的假死）|
| 难度 | 中 — 独立模块 `simple_lmk.c` + 几个 hook 点 |
| 风险 | **中** — 可能误杀正在用的后台（如音乐播放器）|
| 来源 | `github.com/kerneltoast/simple_lmk`（Sultan Alsawaf）|
| 注意 | 需要 `CONFIG_MMU` + 改 `mm/oom_kill.c` 和 `drivers/staging/android/lowmemorykiller.c` |

### 3. Hot-Cold Split — 推荐度 ⭐

| | |
|---|---|
| 是什么 | 把内存页按"热/冷"分开管理 |
| 原理 | 活跃页和冷页分到不同的 LRU 链表，回收时优先动冷页 |
| 收益 | 减少回收开销，减少热页被误回收 |
| 难度 | 中 — 改 `mm/swap.c` / `mm/vmscan.c` |
| 风险 | 中 |
| 来源 | 与 Simple_LMK 同作者，部分包含在其仓库里 |

### 4. BORE 调度器 — 推荐度 ⭐⭐

| | |
|---|---|
| 是什么 | Burst-Oriented Response Enhancer，改进 CFS 的 vruntime 计算 |
| 原理 | 记录任务的"突发度"，突发型任务（用户交互）获得更高权重 |
| 收益 | 界面更跟手，尤其重负载下 |
| 难度 | 中 — 改 `kernel/sched/fair.c` 的 `update_curr` / `place_entity` |
| 风险 | **中** — 动核心调度器，可能影响核间负载均衡 |
| 来源 | `github.com/firelzrd/bore-scheduler`（需确认 4.19 分支）|
| 注意 | 4.19 没有 `CONFIG_SCHED_BORE`，要自己加 Kconfig |

---

## 二、源码改宏（不是 patch，但需要重编）

### 5. PELT 半衰期 32ms → 16ms — 推荐度 ⭐⭐⭐

| | |
|---|---|
| 是什么 | 缩短调度器"记忆"窗口，负载变化后频率回落更快 |
| 改动位置 | `kernel/sched/pelt.h` |
| 关键点 | **两个宏必须一起改**，否则 util 计算溢出 |

```c
/* 原值 */
#define LOAD_AVG_PERIOD 32
#define LOAD_AVG_MAX 47742   /* maximum possible load avg */

/* 改成 16 时，LOAD_AVG_MAX 必须重算，约 */
#define LOAD_AVG_PERIOD 16
#define LOAD_AVG_MAX 23500    /* 近似值，需按公式精确算 */
```

**为什么不能像网上那样加 `delta <<= 1`**：
`delta >>= 10` 是纳秒转 PELT 周期单位，和半衰期无关。
在后面加 `delta <<= 1` 只是把时间跨度翻倍，会让负载计算错误。

**准确公式**（`Documentation/scheduler/sched-pelt.c` 里有生成器）：
```
LOAD_AVG_MAX = 1024 * (1 - (1 - 1/2)^(LOAD_AVG_PERIOD*... )) 的收敛值
```
实际做法：编译 `sched-pelt` 工具生成。

**收益**：降功耗（频率回落快）。
**风险**：低（前提是两个宏配对正确）。

### 6. CPU 频率表调整（降压 / 超频）— 推荐度 ✗

| | |
|---|---|
| 改动位置 | `arch/arm64/boot/dts/vendor/qcom/kona-opp.dtsi`（或类似）|
| 收益 | 降压省电、超频提性能 |
| 风险 | **高** — 电压不足会重启/死机，超频会过热 |
| 判断 | **thyme 散热一般，不建议** |

### 7. UFS Write Booster — 推荐度 ⭐

| | |
|---|---|
| 改动位置 | `arch/arm64/boot/dts/vendor/qcom/*ufs*.dtsi` 里的 `write_booster` 参数 |
| 收益 | 顺序写速度提升 |
| 风险 | 低 |
| 前提 | 需确认 UFS 型号支持（Micron/Samsung 部分支持）|

---

## 三、技术上不可行（backport 成本过高）

| 功能 | 为什么不行 |
|---|---|
| **MGLRU** (`CONFIG_LRU_GEN`) | 5.15 引入，重写了整个 LRU 回收路径，backport 需要改 `mm/` 下十几个文件，且依赖 folio（5.16+）|
| **NTFS3** | 5.15 引入，依赖 iomap 子系统（4.19 没有完整 iomap）|
| **CFI_CLANG** | 需要编译器插桩 + 内核支持，4.19 arm64 完全没有基础设施 |
| **MPTCP 主线版** | 5.6 引入，4.19 只有 out-of-tree 的 v0.9x（完全不同的代码库）|

---

## 四、不推荐做的（有更好替代）

| 项 | 为什么不 |
|---|---|
| **内核级 wakelock 屏蔽** | 在 `wakeup_source_activate` 里提前 return 会破坏 `ws->active` / `active_count` / `start_time`，导致 suspend 判定错乱；拦 `qcom_rx_wakelock` 等于关掉 WiFi 息屏接收 |
| **绕过 mi_thermald 限频** | 骁龙 870 硬件层仍会降频，软件绕过只会更烫、降频更狠 |
| **`sugov_cpu_is_busy` 返回 false** | 该函数本来就是防频率抖动的，强制 false 反而更耗电 |
| **`popp_enabled = false`** | POPP 是高通 GPU 性能优化，关掉是降性能 |

**wakelock 的正确做法**：userspace 的 Wakelock Blocker（Magisk 模块），按名字屏蔽，不动内核。

---

## 五、实施建议（按顺序）

```
第 1 步  SSG 调度器        ← 难度低、风险低、收益明显，先做这个
第 2 步  PELT 16ms         ← 改两个宏，降功耗
第 3 步  Simple_LMK        ← 收益中，风险中，看需求
第 4 步  BORE              ← 收益中，改核心调度器，谨慎
第 5 步  Hot-Cold Split    ← 配套 Simple_LMK
```

**每一项都应该单独编译、单独测试**，不要一次全上——出问题无法定位。

---

## 六、验证 patch 是否生效

```bash
# SSG
cat /sys/block/sda/queue/scheduler        # 应含 [ssg]
echo ssg > /sys/block/sda/queue/scheduler

# Simple_LMK
dmesg | grep -i simple_lmk

# BORE（如果加了 Kconfig）
zcat /proc/config.gz | grep BORE

# PELT（无法直接看，只能通过功耗/频率曲线观察）
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq
```
