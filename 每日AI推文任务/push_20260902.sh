#!/bin/bash
# 推送9月2日AI新闻文章到微信公众号草稿箱
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
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_dark_cinematic_16_9_cover_im_2026-09-02T00-56-41.png"
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "封面上传成功,thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON
TITLE="25%降价、10亿机器人与Agent手机：AI正在重写规则"
DIGEST="Anthropic Fable 5.1降价25%冲刺IPO；OpenAI断供Cursor引编程AI洗牌；英伟达35亿美元绑联发科；马斯克预测十年内人形机器人10亿台；努比亚NaviX Ultra成全球首款AI智能体手机。"
python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-09-02.html /tmp/draft_20260902.json "$TITLE" "$DIGEST"

# Step 4: 创建草稿
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260902.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260902.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo "draft_media_id: $DRAFT_MEDIA_ID"
