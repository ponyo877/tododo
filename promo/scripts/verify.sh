#!/bin/sh
# App Store プレビューの規格（886×1920・H.264 High 4.0・30fps・15〜30秒）を ffprobe で検査
set -e
cd "$(dirname "$0")/.."
f=out/deliver/tododo-appstore-preview-886x1920.mp4
ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,profile,level,width,height,r_frame_rate,pix_fmt -show_entries format=duration -of default=nw=1 "$f"
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$f")
awk -v d="$dur" 'BEGIN{ if (d < 15 || d > 30) { print "NG: duration " d; exit 1 } else print "OK: duration " d }'
