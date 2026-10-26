#!/bin/bash
# 推送 2026-08-01 AI新闻文章到公众号草稿箱
set -e
cd /Users/luzheqi/WorkBuddy/每日AI推文任务
set -a && source .env && set +a
cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

TOKEN=$(get_wechat_token)
COVER='/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_professional_minimalist_tech_2026-08-01T02-51-07.png'
THUMB_MEDIA_ID=$(upload_wechat_image "$TOKEN" "$COVER" | jq -r '.media_id')

TITLE='机器人学会走路，AI自己降价，千人联合喊停'
DIGEST='谷歌让机器人从脚趾控制到指尖，DeepSeek靠后训练让Agent翻六倍，字节和MiniMax同天发布视频AI，1100名AI核心员工联名请愿减速——2026年8月1日，AI世界同时上演技术狂飙和安全反思'

/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py \
  "$THUMB_MEDIA_ID" \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-08-01.html \
  /tmp/draft_20260801.json \
  "$TITLE" \
  "$DIGEST"

create_draft "$TOKEN" "/tmp/draft_20260801.json"
rm -f /tmp/draft_20260801.json
echo "推送完成"
