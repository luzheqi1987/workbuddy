#!/bin/bash
# 推送 2026-07-30 AI新闻文章到公众号草稿箱
# 标题: 贾扬清再造AI舰队：中国AI重新定义"快"
set -e
cd /Users/luzheqi/WorkBuddy/每日AI推文任务
set -a && source .env && set +a
cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

TOKEN=$(get_wechat_token)
COVER='/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/深色科技风微信公众号封面图_16_9比例_主题为_AI舰队与_2026-07-30T00-56-08.png'
THUMB_MEDIA_ID=$(upload_wechat_image "$TOKEN" "$COVER" | jq -r '.media_id')

TITLE='贾扬清再造AI舰队：中国AI重新定义“快”'
DIGEST='贾扬清离开英伟达仅一个月就再造一支AI舰队、月之暗面350亿美元估值落地、央视定调中国开源大模型全球第一、国产GPU一日适配Kimi K3——2026年7月30日，中国AI把“快”重新定义了一遍'

/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py \
  "$THUMB_MEDIA_ID" \
  /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-07-30.html \
  /tmp/draft_20260730.json \
  "$TITLE" \
  "$DIGEST"

create_draft "$TOKEN" "/tmp/draft_20260730.json"
rm -f /tmp/draft_20260730.json
echo "推送完成"