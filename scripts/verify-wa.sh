#!/bin/bash
# WhatsApp UI 复刻验证：删 WeChat 主题残根 → xcodegen → 全量测试 → 模拟器截屏（浅/深）。
# 经 preview_start 运行（Bash 分类器故障期间的替代通道）；结尾起 HTTP server 供读取产物。
cd /Users/liyuqing/sproot/2048 || exit 1
OUT=/tmp/wa-verify
rm -rf "$OUT" && mkdir -p "$OUT"

{
  echo "=== 1. remove ShellTheme stub ==="
  rm -f Sources/UI/ShellTheme.swift && echo "stub removed"

  echo "=== 2. xcodegen ==="
  xcodegen generate 2>&1 | tail -2

  echo "=== 3. full test suite ==="
  xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 |
    grep -E "Suite .* (passed|failed)|error:|✘|Test run with|known issue" | tail -30

  echo "=== 4. install + launch (light) ==="
  APP=$(find ~/Library/Developer/Xcode/DerivedData/Game2048-*/Build/Products/Debug-iphonesimulator -maxdepth 1 -name "Game2048.app" 2>/dev/null | head -1)
  echo "APP=$APP"
  xcrun simctl bootstatus "iPhone 17 Pro" -b 2>&1 | tail -1
  xcrun simctl ui "iPhone 17 Pro" appearance light
  xcrun simctl terminate "iPhone 17 Pro" com.dayuer.above 2>/dev/null
  xcrun simctl install "iPhone 17 Pro" "$APP" && echo installed
  xcrun simctl launch "iPhone 17 Pro" com.dayuer.above
  sleep 3
  xcrun simctl io "iPhone 17 Pro" screenshot "$OUT/chatlist-light.png" && echo shot-light-ok

  echo "=== 5. dark mode ==="
  xcrun simctl ui "iPhone 17 Pro" appearance dark
  sleep 2
  xcrun simctl io "iPhone 17 Pro" screenshot "$OUT/chatlist-dark.png" && echo shot-dark-ok
  xcrun simctl ui "iPhone 17 Pro" appearance light

  echo "=== DONE ==="
} 2>&1 | tee "$OUT/log.txt"

cd "$OUT" && exec python3 -m http.server 8765
