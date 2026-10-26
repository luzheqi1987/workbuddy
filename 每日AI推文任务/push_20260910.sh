#!/bin/bash
# 推送9月10日AI新闻文章到微信公众号草稿箱
set -a
source /Users/luzheqi/WorkBuddy/每日AI推文任务/.env
set +a

cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

# Step 1: 获取access_token
TOKEN=$(get_wechat_token)
if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
    echo "获取token失败，请检查IP白名单设置"
    exit 1
fi
echo "Token获取成功"

# Step 2: 上传封面图
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_dark_cinematic_technology_co_2026-09-10T01-13-04.png"
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "封面上传成功,thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON
TITLE="OpenAI搬芯片厂到首尔，DeepMind把基因算了一遍"
DIGEST="OpenAI与三星深化合作量产自研芯片；DeepMind把90亿种基因突变一次性算完；DeepSeek V4.1 Flash发布Flash系列再降60%；字节拿下296亿美元银团贷款AI算力出海；智元发布AGILE2.0感控一体模型。"
WECHAT_AUTHOR="行走的轮子" python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-09-10.html /tmp/draft_20260910.json "$TITLE" "$DIGEST"

# Step 4: 创建草稿
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260910.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260910.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo "draft_media_id: $DRAFT_MEDIA_ID"