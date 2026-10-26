#!/bin/bash
# 推送7月24日AI新闻文章到微信公众号草稿箱
# 标题:AI一夜拆墙:从Anthropic的AMD奇迹,到机器人的春熙路 (全角标点)

set -a
source /Users/luzheqi/WorkBuddy/每日AI推文任务/.env
set +a

cd /Users/luzheqi/.workbuddy/plugins/marketplaces/experts/plugins/wechat-official-account-expert/skills/mp-draft-push
source ./scripts.sh

# Step 1: 获取access_token
echo "获取access_token..."
TOKEN=$(get_wechat_token)
if [[ "$TOKEN" == "null" || -z "$TOKEN" ]]; then
    echo "获取token失败，请检查IP白名单设置"
    echo "当前IP需添加到：微信公众平台 -> 设置与开发 -> 基本配置 -> IP白名单"
    exit 1
fi
echo "Token获取成功"

# Step 2: 上传封面图
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_minimalist_professional_tech_2026-07-24T00-54-39.png"
echo "上传封面图..."
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "封面上传成功,thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON (标题与摘要已使用全角标点)
echo "构建草稿JSON..."
/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-07-24.html /tmp/draft_20260724.json "AI一夜拆墙:从Anthropic的AMD奇迹,到机器人的春熙路" "Claude周末打通AMD、阿里跑通2万亿、机器人走上春熙路:算力的墙、工厂的手、街头的机器人正在被AI一起拆掉"

# Step 4: 创建草稿
echo "创建草稿..."
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260724.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260724.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo ""
echo "文章信息"
echo "- 标题: AI一夜拆墙:从Anthropic的AMD奇迹,到机器人的春熙路"
echo "- 摘要: Claude周末打通AMD、阿里跑通2万亿、机器人走上春熙路:算力的墙、工厂的手、街头的机器人正在被AI一起拆掉"
echo "- 草稿 media_id: $DRAFT_MEDIA_ID"
echo ""
echo "前往公众号后台查看并发布:"
echo "   https://mp.weixin.qq.com (登录后点击内容管理 -> 草稿箱)"