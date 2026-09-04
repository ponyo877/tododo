#!/bin/sh
# Remotion の ProRes 出力を各配信先の規格に書き出す
set -e
cd "$(dirname "$0")/.."
mkdir -p out/deliver
if [ -f out/AppStorePreview.mov ]; then
  ffmpeg -y -v error -i out/AppStorePreview.mov -c:v libx264 -profile:v high -level:v 4.0 -pix_fmt yuv420p -r 30 \
    -b:v 11M -maxrate 12M -bufsize 22M -x264-params keyint=60 -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
    -c:a aac -b:a 256k -ar 48000 -ac 2 -movflags +faststart out/deliver/tododo-appstore-preview-886x1920.mp4
fi
if [ -f out/SocialPromo.mov ]; then
  ffmpeg -y -v error -i out/SocialPromo.mov -c:v libx264 -crf 17 -r 30 -pix_fmt yuv420p -c:a aac -b:a 192k -movflags +faststart out/deliver/tododo-social-1080x1920.mp4
fi
ls -la out/deliver
