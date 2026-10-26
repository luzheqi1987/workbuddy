#!/bin/bash
# 推送 2026-07-29 AI新闻文章到公众号草稿箱
# 标题: 硅谷千人联名踩刹车：当造AI的人开始害怕AI
set -e
cd /Users/luzheqi/WorkBuddy/每日AI推文任务
set -a && source .env && set +a
cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

TOKEN=$(get_wechat_token)
COVER="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/Dark_technology_WeChat_article_2026-07-29T01-52-11.png"
THUMB_MEDIA_ID=$(upload_wechat_image "$TOKEN" "$COVER" | jq -r '.media_id')

/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py \
  "$THUMB_MEDIA_ID" \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-07-29.html \
  /tmp/draft_20260729.json \
  "硅谷千人联名踩刹车：当造AI的人开始害怕AI" \
  "1134名AI工程师联名请愿控速、奥特曼首次表态支持、Hugging Face索赔1亿美元、中国大模型全球份额超六成、比亚迪人形机器人即将亮相——2026年7月29日，当造AI的人最先踩下刹车"

create_draft "$TOKEN" "/tmp/draft_20260729.json"
rm -f /tmp/draft_20260729.json
echo "推送完成"
