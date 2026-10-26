#!/bin/bash
# 推送9月1日AI新闻文章到微信公众号草稿箱
# 标题: 芯片结盟、广告十亿、机器人出海：AI换挡提速

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
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_dark_cinematic_16_9_cover_im_2026-09-01T01-21-50.png"
echo "上传封面图..."
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "封面上传成功,thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON
echo "构建草稿JSON..."
/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-09-01.html /tmp/draft_20260901.json "芯片结盟、广告十亿、机器人出海：AI换挡提速" "英伟达35亿绑联发科造XPU生态；ChatGPT广告破10亿；欧盟列ChatGPT为VLOSE；高盛上调人形机器人至650万台；银河通用开店香港。"

# Step 4: 创建草稿
echo "创建草稿..."
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260901.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260901.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo ""
echo "文章信息"
echo "- 标题: 芯片结盟、广告十亿、机器人出海：AI换挡提速"
echo "- 摘要: 英伟达35亿绑联发科造XPU生态；ChatGPT广告破10亿；欧盟列ChatGPT为VLOSE；高盛上调人形机器人至650万台；银河通用开店香港。"
echo "- 草稿 media_id: $DRAFT_MEDIA_ID"
echo ""
echo "前往公众号后台查看并发布:"
echo "   https://mp.weixin.qq.com (登录后点击内容管理 -> 草稿箱)"
