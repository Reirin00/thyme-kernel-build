# thyme (Mi 10S / 4.19.157) 自定义内核功能清单

> 针对 `Dowsion-dev/mi10s` / `cctv18/kernel_xiaomi_sm8250_mod` / `badelXia/android_kernel_xiaomi_thyme`
> 三个源码树，4.19.157 基线。

---

## 一、你点名的 5 个

### 1. 零宽修复（Unicode zero-width bypass fix）

| | |
|---|---|
| 是什么 | 修复内核文件名处理中的 Unicode 零宽字符绕过漏洞（可绕过文件访问控制/黑名单） |
| 上游 | `ITxiao6666/Unicode_bypass_Fix`（46★） |
| 补丁 | `unicode-bypass_fix_5.10-6.12通用.patch` + `unicode_bypass_fix2.patch`（**6.1 以下要两个都打**）|
| 4.19 可行性 | ⚠️ **补丁只覆盖 5.10–6.12**，4.19 的 `fs/namei.c` / `fs/libfs.c` 结构不同，需要手工适配 |
| 代价 | **文件查找性能下降**（作者自己标注）|
| 结论 | 能打，但要改；收益是安全加固，日常用感知不到，性能有损 |

### 2. BBG（Baseband-guard）

| | |
|---|---|
| 是什么 | 第三方 LSM，保护 baseband / bootloader 分区不被写入（防格机）|
| 上游 | `fatalcoder524/Baseband-guard`、`vc-teahouse/Baseband-guard` |
| 开关 | `CONFIG_BBG=y`，并在 `CONFIG_LSM` 里加 `baseband_guard` |
| 🔴 **重大风险** | **在 f2fs 上有 NULL 指针崩溃 bug**：`bb_inode_rename` → `f2fs page_get_link(dentry, inode, NULL)`，f2fs 不处理 NULL 第三参数 → **kernel panic** |
| 触发条件 | **任何进程 rename 一个 symlink 就会崩**（dpkg、部分 App 的包操作）|
| 症状 | 随机重启，`bootreason=reboot`，`/proc/last_kmsg` 里能看到 `bb_inode_rename+0x120/0x234` |
| 修复 | defconfig 里 `# CONFIG_BBG is not set`，并从 `CONFIG_LSM` 字符串删掉 `baseband_guard` |
| 结论 | **不建议打**。你现在最怕的就是系统不稳定，这个 bug 是随机的、难复现的 |

### 3. BBR（TCP 拥塞控制）

| | |
|---|---|
| 是什么 | Google 的 TCP 拥塞控制算法，用带宽+延迟建模代替丢包判断，移动网络下吞吐和延迟都更好 |
| 开关 | `CONFIG_TCP_CONG_BBR=y` + `CONFIG_DEFAULT_TCP_CONG="bbr"` |
| 4.19 可行性 | ✅ **原生支持**（4.9+ 就有），不用打补丁 |
| 额外可加 | `CONFIG_TCP_CONG_BBR2=y`（BBRv2，需要额外 patch，4.19 有社区移植）|
| 配套 | `CONFIG_NET_SCH_FQ=y`（BBR 需要 fq 队列才发挥）|
| 结论 | ✅ **零风险，强烈建议加**。这是最能感知到的提升 |

### 4. 内存优化（具体做什么需要选）

| 子项 | config | 4.19 | 效果 | 风险 |
|---|---|---|---|---|
| ZRAM 换 zstd | `CONFIG_ZRAM_DEF_COMP_ZSTD` + `CONFIG_CRYPTO_ZSTD` | ✅ | 压缩率↑，同内存多塞 App | 低（略吃 CPU）|
| ZRAM 换 lz4 | `CONFIG_ZRAM_DEF_COMP_LZ4` | ✅ | 速度优先 | 低 |
| Simple_LMK | 需 patch（Sultan）| ✅ | 低压时直接杀后台，减少卡顿 | 中（可能误杀）|
| Hot-Cold Split | 需 patch | ✅ | 分离热/冷页，减少回收开销 | 中 |
| MGLRU | `CONFIG_LRU_GEN` | ❌ **不支持 4.19**（5.15+）| — | — |
| KSM | `CONFIG_KSM=y` | ✅ | 合并重复页 | 低（吃 CPU）|
| 调 vm.swappiness / watermark | 不改内核，运行时 | — | 立竿见影 | 无 |

**建议**：ZRAM 换 zstd + 运行时调 `swappiness`，别碰 Simple_LMK（4.19 上移植版稳定性未知）。

### 5. SUSFS

| | |
|---|---|
| 是什么 | SukiSU/KernelSU 的**内核级隐藏补丁**，隐藏 root、Zygisk、LSPosed、su 路径、挂载点 |
| 上游 | `simonpunk/susfs4ksu` |
| 4.19 可行性 | ⚠️ **需要核实分支**。SUSFS 主力维护 GKI 5.10+，4.19 属于老的 `kernel-4.19` 分支，功能可能不全 |
| 依赖 | 必须配 KernelSU / SukiSU 内核集成（不能单独用）|
| 效果 | 银行 App、微信、部分游戏的反 root 检测能过 |
| 结论 | 能加，但要先确认 4.19 分支的完整性；和 KernelSU 一起上 |

---

## 二、还能加的（按性价比排序）

### A 类：零风险 / 几乎无副作用

| 功能 | config | 说明 |
|---|---|---|
| BBR + fq | 见上 | 网络加速，最推荐 |
| EROFS | `CONFIG_EROFS_FS=y` | 只读压缩文件系统，读得快、省空间 |
| ZSTD 压缩 | `CONFIG_ZSTD_COMPRESS/DECOMPRESS` | ZRAM、EROFS、内核解压都用 |
| LZ4 / LZ4HC | 已有 | ZRAM 快速压缩 |
| NTFS / EXFAT | `CONFIG_NTFS3_FS` / `CONFIG_EXFAT_FS` | 挂 U 盘 |
| USB 串口 | `CONFIG_USB_SERIAL_CH341` / `FTDI_SIO` / `PL2303` / `CP210X` | 接开发板、调试线 |
| IPSet | `CONFIG_IP_SET` | 防火墙高效规则，广告拦截类工具依赖 |
| WireGuard | `CONFIG_WIREGUARD` | 内核级 VPN，省电 |
| F2FS realtime discard | `CONFIG_F2FS_...` | TRIM 更快，闪存寿命/速度 |
| UFS 读写增强 | Qualcomm `ufs-qcom` 调参 | 顺序读写提升 |

### B 类：有效但有取舍

| 功能 | 说明 | 取舍 |
|---|---|---|
| BORE 调度器 | 突发优先，界面更跟手 | 4.19 需要移植版，核间负载均衡可能变差 |
| SSG I/O 调度器 | UFS 低延迟，App 启动快 | 牺牲公平性，大文件传输变慢 |
| CANBus / USB-CAN | 嵌入式折腾 | 日常用不到，占内存 |
| LXC / Docker | 容器 | 需要额外 namespace/cgroup config，占内存 |
| CIFS / NFS / SMB | 挂网络盘 | 增加攻击面 |
| 编译优化 `-O3` / LTO | 更快 | LTO 在 4.19 + clang 上容易炸，不建议 |

### C 类：不建议

| 功能 | 原因 |
|---|---|
| **BBG** | f2fs NULL deref，随机死机 |
| **MGLRU** | 4.19 根本没有 |
| **KASAN / DEBUG 选项** | 性能和内存开销巨大，只适合调试 |
| **超频** | thyme 散热一般，且 4.19 的 cpufreq 表改动容易锁频 |
| **dtbo 重编** | 已知会导致锁屏闪最高亮度、手势失效、卡槽无信号 |

---

## 三、推荐组合（保守稳妥版）

```
必加：BBR + fq、EROFS、ZSTD、IPSet、WireGuard、F2FS discard
可选：ZRAM zstd、NTFS/EXFAT、USB 串口
要 root 隐藏：KernelSU/SukiSU + SUSFS（先核实 4.19 分支）
跳过：BBG、MGLRU、Simple_LMK、零宽补丁（性价比低 + 有坑）
```

## 四、关键提醒

1. **thyme 的「电量卡 1%」bug**：PM8150 GEN4 电量计问题，必须用已修复的分支（`yspbwx2010` 维护的那个）
2. **不要刷编译产物的 `dtbo.img`**
3. **BBG 的 bug 是真的**（XDA S25 用户实测：`dpkg` 装包就 panic），不是理论风险
4. 零宽补丁作者明确写了「会造成文件查找性能下降」
5. 编译走 GitHub Actions（本机 2 核 3.6G 编不了）
