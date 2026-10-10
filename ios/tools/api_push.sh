#!/usr/bin/env bash
# 经 GitHub Contents API 推送文件到 liudubin/zcode-remote(绕过被墙的 github.com 推送)。
# 用法: bash ios/tools/api_push.sh <文件路径>... <commit message>
# 防护: ①锚定仓库根(脚本位置定位,与 cwd 无关) ②base64/文件缺失即中止 ③空文件拒绝推送
set -euo pipefail

REPO=liudubin/zcode-remote
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

MSG="${@: -1}"
FILES=("${@:1:$#-1}")
[ ${#FILES[@]} -ge 1 ] || { echo "usage: api_push.sh <file...> <message>"; exit 1; }

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "ABORT: $f not found (repo root: $ROOT)"; exit 1; }
  [ -s "$f" ] || { echo "ABORT: $f is empty, refuse to push"; exit 1; }
  sha=$(gh api "repos/$REPO/contents/$f?ref=main" --jq .sha 2>/dev/null || true)
  content=$(base64 -w0 "$f")
  [ -n "$content" ] || { echo "ABORT: base64 of $f empty"; exit 1; }
  if [ -n "$sha" ]; then
    gh api -X PUT "repos/$REPO/contents/$f" \
      -f message="$MSG" -f content="$content" -f branch=main -f sha="$sha" --jq .commit.sha >/dev/null
  else
    gh api -X PUT "repos/$REPO/contents/$f" \
      -f message="$MSG" -f content="$content" -f branch=main --jq .commit.sha >/dev/null
  fi
  echo "pushed: $f ($(wc -c < "$f") bytes, commit for it above)"
done
