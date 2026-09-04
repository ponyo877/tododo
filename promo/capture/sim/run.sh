#!/bin/bash
# 使い方: promo/capture/sim/run.sh <take>
# シミュレータを初期状態にして録画を開始し、XCUITest（DemoFlow）で操作、timeline.json と raw.mov を残す
set -euo pipefail
TAKE=${1:?take name}
SIM=${SIM:-C11037E5-B6B5-44D2-ABAA-6C299C01C784}
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
DIR="$ROOT/promo/captures/$TAKE"
APP="$ROOT/build/Build/Products/Release-iphonesimulator/MyTodo.app"
mkdir -p "$DIR"

xcrun simctl boot "$SIM" 2>/dev/null || true
xcrun simctl bootstatus "$SIM" >/dev/null
xcrun simctl terminate "$SIM" com.ponyo877.MyTodo 2>/dev/null || true
xcrun simctl uninstall "$SIM" com.ponyo877.MyTodo 2>/dev/null || true
# ユーザードメイン側の古い設定も消す（初回起動時に cfprefsd がこちらを拾うため）
xcrun simctl spawn "$SIM" defaults delete com.ponyo877.MyTodo 2>/dev/null || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl ui "$SIM" appearance light
xcrun simctl status_bar "$SIM" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularMode active --cellularBars 4

xcrun simctl io "$SIM" recordVideo --codec h264 --mask ignored --force "$DIR/raw.mov" &
REC=$!
sleep 1.5
date +%s.%N > "$DIR/rec_start"

TEST_RUNNER_PROMO_TIMELINE="$DIR/timeline.json" \
xcodebuild test-without-building -project "$ROOT/MyTodo.xcodeproj" -scheme MyTodo \
  -destination "platform=iOS Simulator,id=$SIM" -derivedDataPath "$ROOT/build" \
  -only-testing:MyTodoUITests/DemoFlow/testDemo 2>&1 | grep -E "Test Case|error:|failed|TEST " | tail -5

sleep 1
kill -INT $REC; wait $REC || true
xcrun simctl status_bar "$SIM" clear
echo "rec_start=$(cat "$DIR/rec_start")"
ffprobe -v error -show_entries format=duration -show_entries stream=width,height,r_frame_rate -of default=nw=1 "$DIR/raw.mov"
python3 - "$DIR" <<'PY'
import json, sys
d = sys.argv[1]
t = json.load(open(f"{d}/timeline.json"))["events"]
rec = float(open(f"{d}/rec_start").read())
for e in t: print(f"{e['t']-rec:7.2f}s  {e['name']}")
PY
