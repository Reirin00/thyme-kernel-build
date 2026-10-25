# FOR WORKBUDDY：thyme 内核云编译闭环交接（2026-10-26 07:2x 快照）

> 本文档自包含。ZCode 会话额度用尽，由你接手继续。任务：小米 10S（thyme）4.19 内核全自动云编译，直到产物通过三项刷前校验。

## 当前状态（接手时）

- **进行中 run：40243727726**（第 2 轮），3/13 步，正在克隆源码
- 第 1 轮（40243355698）失败于 defconfig：`ccache: not found` → 已修复（依赖加 ccache，提交 54dc6a1）→ 触发本轮
- 仓库：`Reirin00/thyme-kernel-build`（Public，main 分支，workflow=`build-thyme.yml`）
- 本地：`/home/reirin/WorkBuddy/偏移量/work/thyme-kernel/`（git 已关联远端）

## 凭证与环境

```bash
export GH_TOKEN='ghp_<PAT见用户/本地会话,勿写入公开仓库>'   # Reirin00, scope: repo+workflow
API="https://api.github.com/repos/Reirin00/thyme-kernel-build"
# 网络正常时直接用；若 github 断连（网关 fake-ip 黑洞）：
#   DoH 查真实 IP: curl -s "https://223.5.5.5/resolve?name=api.github.com&type=A" (→20.205.243.168)
#   所有 curl 加 --resolve api.github.com:443:20.205.243.168
# git 推送:
export GIT_SSH_COMMAND="ssh -F /dev/null -i $HOME/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"
# remote 已配: ssh://git@ssh.github.com:443/Reirin00/thyme-kernel-build.git
```

## 闭环流程（继续执行）

### 1. 轮询当前 run（40243727726）

```bash
while true; do
  RES=$(curl -s -m 20 -H "Authorization: Bearer $GH_TOKEN" "$API/actions/runs/40243727726")
  ST=$(echo "$RES"|python3 -c "import json,sys;print(json.load(sys.stdin)['status'])")
  CC=$(echo "$RES"|python3 -c "import json,sys;print(json.load(sys.stdin).get('conclusion'))")
  echo "$(date +%H:%M:%S) $ST/$CC"; [ "$ST" = completed ] && break; sleep 60
done
```

### 2a. 失败分支：拉日志→修→推→重触发

```bash
curl -sL -m 60 -H "Authorization: Bearer $GH_TOKEN" "$API/actions/runs/<RUN_ID>/logs" -o /tmp/logs.zip
unzip -o /tmp/logs.zip -d /tmp/logs && grep -rhE 'error:|Error [0-9]' /tmp/logs | head
# 修 .github/workflows/build-thyme.yml → git add -A && git commit -m "fix: ..." → git push origin main
curl -s -X POST -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/actions/workflows/build-thyme.yml/dispatches" -d '{"ref":"main"}' -o /dev/null -w '%{http_code}\n'  # 期望 204
# 回到步骤 1 用新 run id（per_page=1 取最新）
```

### 2b. 成功分支：下载产物 + 三项铁律校验

```bash
ART_ID=$(curl -s -H "Authorization: Bearer $GH_TOKEN" "$API/actions/runs/<RUN_ID>/artifacts" | python3 -c "import sys,json;print(json.load(sys.stdin)['artifacts'][0]['id'])")
curl -sL -H "Authorization: Bearer $GH_TOKEN" "$API/actions/artifacts/$ART_ID/zip" -o bundle.zip
unzip -o bundle.zip && rm bundle.zip   # artifact 是 zip-of-zip, 解出 thyme-kernel-N.zip
Z=$(ls -t thyme-kernel-*.zip | head -1)
# 校验① AK3 结构: unzip -l "$Z" 须含 META-INF/com/google/android/update-binary + anykernel.sh + Image
# 校验② 无 dtbo:  unzip -l "$Z" | grep -qi dtbo && echo FATAL || echo OK
# 校验③ vermagic:  unzip -p "$Z" Image > /tmp/Image; strings /tmp/Image | grep -m1 "Linux version 4.19.157-perf "
#   必须精确 "4.19.157-perf "(带空格, 无 +/dirty 尾巴); Image 30-60MB
```

## 本 workflow 的内容（已锁定，勿随意改）

- 源：cctv18/kernel_xiaomi_sm8250_mod @ android14-lineage22-mod，defconfig=thyme_defconfig
- ABI/CRC 安全：**无 UCLAMP**（改了会炸 WiFi 模块 CRC）、KSM 关、vermagic 锁 `4.19.157-perf`
- config：BBR 默认+fq、ZRAM-LZ4、ZSTD、Kyber、WQ_POWER_EFFICIENT（--enable NET_SCH_FQ_CODEL 和 DEFAULT_FQ 若 olddefconfig 后被丢不算致命,校验步骤没卡它们）
- 11 项函数体级源码补丁（Python heredoc, 全部 SKIP 兜底）: -O3/cortex-a77、WALT RECENT、PELT 16ms、mi_thermald 解锁、wakelock 黑名单、GPU 56ms、input_boost 40ms、sugov 去粘滞、page_cluster=0、binder/bus 静默、NAPI 1000us
- 打包：easterNday/AnyKernel3@thyme 分支, 强制无 dtbo, zip 名 thyme-kernel-<run#>.zip

## 预期与历史坑

- 全程约 30-50 分钟（ubuntu-22.04, Proton-Clang, 首编无缓存）
- 已修：ccache 缺失（127）。其他潜在坑：olddefconfig 丢 config（校验步骤会精确指出哪个 CONFIG 没生效——对照上面"内容"清单放开或改校验）、4.19 老内核对新 binutils 兼容（若 LLD 报错考虑 LD=ld.lld 之外再议）
- 刷机（校验全过后提示用户）：TWRP 刷 zip 或 fastboot 刷 boot; 救砖=刷回备份 boot_a/b
- 完成后提醒用户撤销 PAT: github.com/settings/tokens（ghp_vf0h…，聊天记录里有明文）
