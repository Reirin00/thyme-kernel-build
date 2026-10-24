# 怎么编译 thyme 自定义内核（GitHub Actions 云编译）

> 本机（2 核 Athlon II / 3.6GB RAM）编不了 4.19 内核，只能云编译。
> 全套配置已验证过上游模板：`xiaoyu-Terry1024/Thyme-Kernel-Builder`

---

## 一、准备工作（5 分钟）

### 1. 新建一个 GitHub 仓库

名字随便，比如 `thyme-kernel-build`，**Public 或 Private 都行**（Private 的 Actions 每月 2000 分钟免费额度够用）。

### 2. 把这两个东西推进去

```
你的仓库/
└── .github/
    └── workflows/
        └── build-thyme.yml     ← 本目录已备好
```

推上去：

```bash
mkdir thyme-kernel-build && cd thyme-kernel-build
git init
mkdir -p .github/workflows
cp /home/reirin/WorkBuddy/偏移量/work/thyme-kernel/.github/workflows/build-thyme.yml .github/workflows/
git add . && git commit -m "add thyme kernel build workflow"
git remote add origin https://github.com/<你的用户名>/thyme-kernel-build.git
git push -u origin main
```

> ⚠️ **不要**把 `thyme_defconfig` 这种内核源码推上来，workflow 会自己去 clone。

### 3. 确认权限

仓库 → Settings → Actions → General → Workflow permissions → 选 **Read and write permissions**（上传 artifact 需要）。

---

## 二、跑编译

```
仓库 → Actions → 左侧 "Build thyme Kernel" → 右侧 "Run workflow"
```

三个开关：

| 参数 | 默认 | 说明 |
|---|---|---|
| `kernel_repo` | `cctv18/kernel_xiaomi_sm8250_mod` | 源码仓库 |
| `kernel_branch` | `android14-lineage22-mod` | 分支 |
| `defconfig` | `thyme_defconfig` | 配置文件 |
| `enable_ksu` | false | 集成 KernelSU（要先想清楚）|
| `apply_features` | **true** | 自动加 BBR/IPSet/KSM/ZSTD/Kyber |

点 **Run workflow**。

**耗时**：约 **40–70 分钟**（4.19 内核 + 无缓存）。

---

## 三、会改哪些 config

`apply_features=true` 时自动追加（已存在的会跳过）：

```config
CONFIG_TCP_CONG_BBR=y
CONFIG_DEFAULT_TCP_CONG="bbr"
CONFIG_NET_SCH_FQ=y

CONFIG_IP_SET=y
CONFIG_IP_SET_MAX=256
CONFIG_NETFILTER_XT_SET=y

CONFIG_KSM=y
CONFIG_ZSTD_COMPRESS=y
CONFIG_ZSTD_DECOMPRESS=y

CONFIG_MQ_IOSCHED_KYBER=y
```

这些都**只新增功能，不改结构体、不动 LOCALVERSION**，所以编出来的内核：
- ✅ 能刷 MIUI 14 / HyperOS 1.0
- ✅ 能刷 LineageOS 21/22/23
- ✅ 能刷 HyperOS 3.0 移植包
- ❌ 不能跨到不同内核版本的 ROM

---

## 四、拿产物

Actions 跑完 → 点进那次 run → 底部 **Artifacts** → 下载 `thyme-kernel-XX.zip`（约 20-30 MB）。

这是一个 **AnyKernel3 直刷包**：

```
thyme-kernel-XX.zip
├── META-INF/com/google/android/update-binary
├── META-INF/com/google/android/updater-script
├── anykernel.sh
├── Image           ← 你编译的内核
└── tools/
```

**注意：包里没有 `dtbo.img`**（故意去掉的，thyme 重编 dtbo 会导致锁屏闪最高亮度、手势失效、卡槽无信号）。

---

## 五、刷入

```
1. 推到手机：adb push thyme-kernel-XX.zip /sdcard/
2. TWRP → Install → 选它 → Swipe
3. 重启
```

刷内核**不需要** Format Data，**不清数据**。

---

## 六、刷完验证

```bash
# 1. BBR 在不在
cat /proc/sys/net/ipv4/tcp_available_congestion_control
# 期望: reno cubic bbr

# 2. 当前用的算法
cat /proc/sys/net/ipv4/tcp_congestion_control
# 期望: bbr

# 3. fq 队列
tc qdisc show | grep fq

# 4. IPSet
cat /proc/net/ip_tables_matches | grep set

# 5. KSM
cat /sys/kernel/mm/ksm/run
# 1=开 0=关

# 6. I/O 调度器
cat /sys/block/sda/queue/scheduler
# 期望括号里是 kyber 或 bfq

# 7. 内核 config 确认（IKCONFIG 已开）
zcat /proc/config.gz | grep -E "TCP_CONG_BBR|NET_SCH_FQ|IP_SET=|KSM="
```

---

## 七、出错怎么办

### 常见编译错误

| 报错 | 原因 | 解决 |
|---|---|---|
| `No rule to make target 'thyme_defconfig'` | 分支不对 / defconfig 名错 | 换 `kernel_branch` 或确认 `arch/arm64/configs/thyme_defconfig` 存在 |
| `clang: error: unknown argument` | proton-clang 版本与 4.19 不匹配 | 换 clang，见下 |
| `error: use of undeclared identifier 'CONFIG_XXX'` | 新功能依赖没开 | 补依赖 config |
| `Killed` / OOM | Actions runner 内存 7GB，一般够；`-j$(nproc)` 是 4 核 | 改 `-j2` |
| `No space left on device` | 源码 + out 超 14GB | 加 `rm -rf out` 重试，或用 `make clean` |

### 换 clang 版本

proton-clang 如果不行，试 AOSP 的：

```yaml
- name: "Clone clang"
  run: |
    git clone --depth=1 https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r487747c.git clang
    echo "$PWD/clang/bin" >> $GITHUB_PATH
```

然后所有 `proton-clang/bin/` 换成 `clang/bin/`。

### 想看完整编译日志

Actions run 页面里每个 step 都能展开，`Build kernel` 那一步会有完整 `make` 输出。

---

## 八、几个关键坑

### ① 不要打包 dtbo.img
thyme 重编 dtbo 已知会导致：
- 锁屏时熄屏，屏幕闪一下最高亮度
- 手势导航失效
- 某个卡槽无信号

workflow 里已经去掉。

### ② 电量卡 1% 的 bug
thyme 用 PM8150 GEN4 电量计，某些内核分支有「电量永远显示 1%」的 bug。

`cctv18/kernel_xiaomi_sm8250_mod` 的 `android14-lineage22-mod` 分支**已经修了**（README 提到 `yspbwx2010` 的修复）。如果刷完电量异常，换分支。

### ③ KernelSU 不是必选
`enable_ksu=false` 也能用 **APatch** 或 **Magisk** 打 boot 补丁 root，不需要重编内核。

真要 KernelSU，再开 `enable_ksu=true`。

### ④ 编译内核 ≠ 换内核版本
这只是基于 4.19.157 加功能，**内核版本号还是 4.19.157**。想升到 5.x/6.x 是不可能的（BSP 不支持）。

---

## 九、备选：用现成模板

不想自己写 workflow，直接 fork：

```
https://github.com/xiaoyu-Terry1024/Thyme-Kernel-Builder
→ fork → Actions → Build kernels → Run workflow
```

它用 `repos/repos.json` 定义 matrix，配置是：

```json
{
  "kernelSource": {
    "name": "DogDay-KernelSU-Proton-release",
    "repo": "https://codeberg.org/DogDayAndroid/android_kernel_xiaomi_thyme",
    "branch": "lineage-20.0",
    "device": "thyme",
    "defconfig": "thyme_defconfig"
  },
  "withKernelSU": true,
  "AnyKernel3": {
    "use": true,
    "release": true,
    "repo": "https://github.com/easterNday/AnyKernel3/",
    "branch": "thyme"
  },
  "toolchains": [{
    "name": "proton-clang",
    "url": "https://github.com/kdrag0n/proton-clang",
    "binPath": ["bin"]
  }],
  "params": {
    "ARCH": "arm64",
    "CC": "proton-clang/bin/clang",
    "externalCommand": {
      "CROSS_COMPILE": "proton-clang/bin/aarch64-linux-gnu-",
      "CROSS_COMPILE_ARM32": "proton-clang/bin/arm-linux-gnueabi-",
      "LD": "proton-clang/bin/ld.lld"
    }
  }
}
```

**但那个模板用的是 Codeberg 的 `lineage-20.0`（Android 13）**，比 `cctv18/android14-lineage22-mod` 旧。
本目录的 workflow 默认用 cctv18 那个，更新一些。

---

## 十、时间线参考

| 阶段 | 耗时 |
|---|---|
| clone 源码（~3GB）| 3–8 分钟 |
| clone 工具链 | 1–2 分钟 |
| make defconfig | 1 分钟 |
| **make -j4（主要耗时）** | **30–60 分钟** |
| AnyKernel3 打包 | 10 秒 |
| 上传 artifact | 1–2 分钟 |
| **合计** | **40–75 分钟** |
