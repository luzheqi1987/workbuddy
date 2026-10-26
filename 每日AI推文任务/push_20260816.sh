#!/bin/bash
# 推送8月16日AI新闻文章到微信公众号草稿箱
# 标题: Cursor卖身、宇树IPO、苹果牵手阿里：AI三件大事

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
    exit 1
fi
echo "Token获取成功"

# Step 2: 上传封面图
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/A_dark__cinematic__minimalist__2026-08-16T01-22-21.png"
echo "上传封面图..."
MEDIA_RESPONSE=$(upload_wechat_image "$TOKEN" "$COVER_IMAGE")
THUMB_MEDIA_ID=$(echo "$MEDIA_RESPONSE" | jq -r '.media_id')
if [[ "$THUMB_MEDIA_ID" == "null" || -z "$THUMB_MEDIA_ID" ]]; then
    echo "封面上传失败: $MEDIA_RESPONSE"
    exit 1
fi
echo "封面上传成功,thumb_media_id: $THUMB_MEDIA_ID"

# Step 3: 构建草稿JSON
TITLE="Cursor卖身、宇树IPO、苹果牵手阿里：AI三件大事"
DIGEST="SpaceX 600亿美元收购Cursor落地；智谱GLM-5.3开源登顶编程与安全；宇树科创板IPO申购火爆，DeepSeek 1.41亿战略入股；苹果联手阿里，国行iPhone专属AI落地在即；影石GO Ultra接入Kira，拇指相机变随身AI。"
echo "构建草稿JSON..."
/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-08-16.html /tmp/draft_20260816.json "$TITLE" "$DIGEST"

# Step 4: 创建草稿
echo "创建草稿..."
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260816.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260816.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo ""
echo "文章信息"
echo "- 标题: $TITLE"
echo "- 摘要: $DIGEST"
echo "- 草稿 media_id: $DRAFT_MEDIA_ID"
echo ""
echo "前往公众号后台查看并发布:"
echo "   https://mp.weixin.qq.com (登录后点击内容管理 -> 草稿箱)"
