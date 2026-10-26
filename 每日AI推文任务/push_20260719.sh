#!/bin/bash
# 推送7月19日AI新闻文章到微信公众号草稿箱
# 使用前需确保当前IP在微信API白名单中
# 在微信公众平台 → 设置与开发 → 基本配置 → IP白名单 中添加当前IP

set -a
source /Users/luzheqi/WorkBuddy/每日AI推文任务/.env
set +a

cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

# Step 1: 获取access_token
echo "获取access_token..."
TOKEN=$(get_wechat_token)
if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
    echo "❌ 获取token失败，请检查IP白名单设置"
    echo "当前IP需添加到：微信公众平台 → 设置与开发 → 基本配置 → IP白名单"
    exit 1
fi
echo "✅ Token获取成功"

# Step 2: 上传封面图
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_professional_minimalist_tech_2026-07-19T01-10-41.png"
echo "上传封面图..."
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "❌ 封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "✅ 封面上传成功，thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON（替换placeholder thumb_media_id）
echo "构建草稿JSON..."
/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-07-19.html /tmp/draft_20260719_final.json "当AI学会边听边说、先想再做、自己造血" "语音全双工、具身双脑协同、推理毛利率70%，AI产业同时跨过三道门槛"

# Step 4: 创建草稿
echo "创建草稿..."
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260719_final.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260719_final.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "❌ 草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "✅ 草稿发布成功！"
echo ""
echo "📝 文章信息"
echo "- 标题：当AI学会边听边说、先想再做、自己造血"
echo "- 摘要：语音全双工、具身双脑协同、推理毛利率70%，AI产业同时跨过三道门槛"
echo "- 草稿 media_id：$DRAFT_MEDIA_ID"
echo ""
echo "📌 前往公众号后台查看并发布："
echo "   https://mp.weixin.qq.com （登录后点击「内容管理」→「草稿箱」）"
