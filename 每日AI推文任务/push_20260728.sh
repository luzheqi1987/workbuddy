#!/bin/bash
# 推送 2026-07-28 AI新闻文章到公众号草稿箱
# 标题: 中国光刻机，今夜亮剑：国产DUV量产，ASML暴跌7%
# 草稿ID: PeRewqDUQFS5dyl78O8bdqIoWVw-HLyXrWdVivq04RAQ7NJnCEYIFagWhUBFa-ps
set -e
cd /Users/luzheqi/WorkBuddy/每日AI推文任务
set -a && source .env && set +a
cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

TOKEN=$(get_wechat_token)
COVER="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/深色科技风微信公众号封面图_16_9比例_主题为国产光刻机突_2026-07-28T01-08-36.png"
THUMB_MEDIA_ID=$(upload_wechat_image "$TOKEN" "$COVER" | jq -r '.media_id')

/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py \
  "$THUMB_MEDIA_ID" \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-07-28.html \
  /tmp/draft_20260728.json \
  "中国光刻机，今夜亮剑：国产DUV量产，ASML暴跌7%" \
  "国产浸没式DUV光刻机迈入量产交付，Claude Code击穿CUDA二十年护城河，三大科技巨头同日亮出AI Agent王牌，美股AI硬件一夜闪崩——2026年7月28日，中国硬科技亮出了最锋利的那把刀"

create_draft "$TOKEN" "/tmp/draft_20260728.json"
rm -f /tmp/draft_20260728.json
echo "推送完成"
