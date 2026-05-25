#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "❌ XcodeGen 未安装。先运行： brew install xcodegen"
  echo "   （或者按 README 里的「手动建工程」方案，不需要 XcodeGen）"
  exit 1
fi

echo "▶︎ 生成 Xcode 工程…"
xcodegen generate

echo "▶︎ 打开 Xcode，按 Cmd-R 运行即可。"
open EnglishCloze.xcodeproj
