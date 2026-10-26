#!/bin/bash
# =============================================================
# thyme (小米 10S) 内核全自动云编译
# 用法:
#   export GH_TOKEN='ghp_xxx'
#   ./auto_build.sh              # 推当前改动 → 触发 → 轮询 → 下载 → 三项校验
#   ./auto_build.sh --no-push    # 不推送，直接触发
# =============================================================
set -uo pipefail

TOKEN="${GH_TOKEN:?需要先 export GH_TOKEN=ghp_xxx（scope: repo + workflow）}"
API="https://api.github.com/repos/Reirin00/thyme-kernel-build"
WF="build-thyme.yml"
OUT="$(cd "$(dirname "$0")" && pwd)/out-kernel"
H=(-H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" -H "User-Agent: curl/8")
NO_PUSH=0
[ "${1:-}" = "--no-push" ] && NO_PUSH=1

cd "$(dirname "$0")" || exit 1
mkdir -p "$OUT"

say() { printf '\033[1;36m▶ %s\033[0m\n' "$*"; }
err() { printf '\033[1;31m✗ %s\033[0m\n' "$*"; }

# ---------- 1. 推送 ----------
if [ $NO_PUSH -eq 0 ]; then
    say "推送本地改动"
    export GIT_SSH_COMMAND="ssh -F /dev/null -i $HOME/.ssh/id_ed25519 \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes"
    if ! git diff --quiet || ! git diff --cached --quiet; then
        git add -A && git commit -m "auto: $(date '+%F %T')" >/dev/null
    fi
    git push origin main 2>&1 | tail -1
fi

# ---------- 2. 触发 ----------
say "触发 workflow"
CODE=$(curl -sS -X POST "${H[@]}" "$API/actions/workflows/$WF/dispatches" \
       -d '{"ref":"main"}' -o /dev/null -w "%{http_code}")
[ "$CODE" = "204" ] || { err "dispatch 失败 HTTP $CODE"; exit 1; }
sleep 8

RID=$(curl -sS "${H[@]}" "$API/actions/runs?per_page=1" | python3 -c "import json,sys;print(json.load(sys.stdin)['workflow_runs'][0]['id'])")
RNUM=$(curl -sS "${H[@]}" "$API/actions/runs/$RID" | python3 -c "import json,sys;print(json.load(sys.stdin)['run_number'])")
say "run #$RNUM  id=$RID"

# ---------- 3. 轮询 ----------
say "等待完成（预计 40-60 分钟）"
START=$(date +%s)
while true; do
    read -r ST CC <<< "$(curl -sS "${H[@]}" "$API/actions/runs/$RID" | python3 -c "
import json,sys;d=json.load(sys.stdin);print(d['status'],d.get('conclusion') or '-')")"
    EL=$(( ($(date +%s)-START)/60 ))
    printf '  [%3dm] %s / %s\n' "$EL" "$ST" "$CC"
    [ "$ST" = "completed" ] && break
    sleep 60
done

# ---------- 4. 结果 ----------
if [ "$CC" != "success" ]; then
    err "编译失败（$CC），拉取日志分析"
    JID=$(curl -sS "${H[@]}" "$API/actions/runs/$RID/jobs" | python3 -c "import json,sys;print(json.load(sys.stdin)['jobs'][0]['id'])")
    mkdir -p _logs
    curl -sSL "${H[@]}" "$API/actions/jobs/$JID/logs" -o "_logs/jobN.log"
    echo "--- 失败步骤 ---"
    curl -sS "${H[@]}" "$API/actions/runs/$RID/jobs" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for j in d.get('jobs',[]):
    for s in j['steps']:
        if s.get('conclusion')=='failure': print('  ✗', s['number'], s['name'])"
    echo "--- 首次错误上下文 ---"
    N=$(grep -n 'error:\|Error [0-9]\|fatal:' "_logs/jobN.log" 2>/dev/null | head -1 | cut -d: -f1)
    [ -n "${N:-}" ] && sed -n "$((N-15)),$((N+3))p" "_logs/jobN.log" | sed 's/^[0-9T:.Z-]* //' | grep -v '^$'
    exit 1
fi

say "编译成功，下载产物"
ART=$(curl -sS "${H[@]}" "$API/actions/runs/$RID/artifacts" | python3 -c "import json,sys;print(json.load(sys.stdin)['artifacts'][0]['id'])")
cd "$OUT"
curl -sSL "${H[@]}" "$API/actions/artifacts/$ART/zip" -o bundle.zip
unzip -o bundle.zip >/dev/null 2>&1 && rm -f bundle.zip
Z=$(ls -t thyme-kernel-*.zip 2>/dev/null | head -1)
[ -n "$Z" ] || { err "解压后没有找到 thyme-kernel-*.zip"; exit 1; }
say "产物: $Z ($(du -h "$Z" | cut -f1))"

# ---------- 5. 三项铁律校验 ----------
say "校验① AK3 结构"
for f in Image anykernel.sh META-INF/com/google/android/update-binary; do
    unzip -l "$Z" | grep -q "$f" && echo "  ✓ $f" || { err "缺 $f"; exit 1; }
done

say "校验② 无 dtbo"
if unzip -l "$Z" | grep -qi dtbo; then err "包含 dtbo，禁止刷入"; exit 1; else echo "  ✓ 无 dtbo"; fi

say "校验③ vermagic"
unzip -o -q "$Z" Image -d .
V=$(strings Image | grep -m1 "Linux version 4.19")
echo "  $V"
echo "$V" | grep -q "4.19.157-perf " || { err "vermagic 不是 4.19.157-perf"; exit 1; }
SZ=$(stat -c%s Image); echo "  Image $((SZ/1024/1024)) MB"
[ "$SZ" -gt 30000000 ] && [ "$SZ" -lt 65000000 ] || { err "Image 大小异常"; exit 1; }

printf '\n\033[1;32m✓ 全部通过\033[0m\n'
printf '产物: %s\n' "$OUT/$Z"
printf '刷机: adb push "%s" /sdcard/  → TWRP Install → 刷完测 WiFi/音频/相机\n' "$OUT/$Z"
