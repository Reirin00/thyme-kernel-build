# 下次继续：thyme 内核编译

> 关机前状态快照。下次开机从这看。

## 一句话

**workflow 已就绪（22 项 config），只差一个 GitHub 仓库，然后就能编。**

---

## 已完成

```
源码定位     cctv18/kernel_xiaomi_sm8250_mod 分支 android14-lineage22-mod
defconfig   arch/arm64/configs/thyme_defconfig（不在 vendor/ 下）
工具链      kdrag0n/proton-clang
打包        easterNday/AnyKernel3 分支 thyme
workflow    work/thyme-kernel/.github/workflows/build-thyme.yml（22 项注入，YAML 已校验）
git         commit 0ff174d，工作区干净
```

## 下次开机先做这三步

### 1. 建 GitHub 仓库（30 秒）

```
https://github.com/new
名字：thyme-kernel-build
⚠️ 不要勾 README / .gitignore / license
```

或者给 PAT（勾 `repo` + `workflow`），全自动。

### 2. 推 workflow

```bash
cd /home/reirin/WorkBuddy/偏移量/work/thyme-kernel

export GIT_SSH_COMMAND="ssh -F /dev/null -i $HOME/.ssh/id_ed25519 \
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"

git remote add origin ssh://git@ssh.github.com:443/Reirin00/thyme-kernel-build.git
git push -u origin main
```

> SSH 22 端口被代理拦（198.18.0.25），**必须走 443**，端口写进 URL。

### 3. 触发

网页：`Actions → Build thyme Kernel → Run workflow`

等 40-75 分钟，下载 Artifacts 里的 `thyme-kernel-N.zip`。

---

## 刷之前必须检查

```bash
unzip -l thyme-kernel-N.zip | grep -i dtbo
# 有 dtbo 就删掉再刷（会导致锁屏闪最高亮度 / 手势失效）
```

## 刷机

```bash
U=/usr/lib/UotanToolbox/Bin/platform-tools/adb
umount -l /dev; sleep 1          # 必须！否则看不到设备
$U devices                        # 应显示 5658b545 recovery
$U push thyme-kernel-N.zip /sdcard/
# TWRP → Install → 选它 → Swipe
```

刷内核**不清数据**，不需要 Format Data。

## 刷完验证

```bash
$U shell 'cat /proc/sys/net/ipv4/tcp_congestion_control'   # 应 bbr（编译默认就是）
$U shell 'cat /sys/block/sda/queue/scheduler'              # 括号里是当前调度器
$U shell 'zcat /proc/config.gz | grep -E "UCLAMP|KYBER|KPROBES"'
$U shell 'uname -r'                                        # 应 4.19.157-perf
```

---

## 22 项 config 清单

```config
# 网络
CONFIG_TCP_CONG_ADVANCED=y
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"        ← 编译默认就启用，不需要运行时设
CONFIG_NET_SCH_FQ=y
CONFIG_NET_SCH_FQ_CODEL=y
CONFIG_TCP_CONG_WESTWOOD=y
CONFIG_TCP_CONG_HTCP=y
CONFIG_TCP_CONG_VEGAS=y
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENTS=y

# 内存
# CONFIG_KSM is not set              ← 强制关（持续扫描吃 CPU）
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y
CONFIG_ZRAM_DEF_COMP_LZ4=y

# 调度 / 省电
CONFIG_UCLAMP_TASK=y
CONFIG_UCLAMP_TASK_GROUP=y
CONFIG_WQ_POWER_EFFICIENT_DEFAULT=y
CONFIG_PM_AUTOSLEEP=y

# I/O  / 挂载
CONFIG_MQ_IOSCHED_KYBER=y
CONFIG_SQUASHFS=y
CONFIG_SQUASHFS_ZSTD=y
CONFIG_CIFS=y
```

---

## 还在讨论、没定的

| 项 | 状态 |
|---|---|
| `CONFIG_LOG_BUF_SHIFT=18` | 建议加（panic 日志从 128KB→256KB），未加 |
| 把 I/O 默认调度器 / swappiness 写进源码 | 可行，未做 |
| SSG 调度器 patch | 推荐，未做 |
| thyme_tune.sh | 已写好，需要 root 才有用 |
| 一加 Ace 3 Pro 内核 | 提示词已备（`PROMPT_CORVETTE_KERNEL.md`），未开始 |

## 关键文档索引

```
HANDOVER_THYME_KERNEL.md              完整技术交接（12 章）
work/thyme-kernel/BUILD.md            操作手册
work/thyme-kernel/ALL_FEATURES_VERIFIED.md   功能全表（三态核对）
work/thyme-kernel/PATCH_FEATURES.md   patch 级功能清单
work/thyme-kernel/thyme_tune.sh       运行时调优脚本
FOR_ZCODE_KERNEL.md                   ZCode 任务书
PROMPT_CORVETTE_KERNEL.md             一加 Ace 3 Pro 提示词
```
