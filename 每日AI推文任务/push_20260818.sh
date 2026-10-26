#!/bin/bash
# 推送8月18日AI新闻文章到微信公众号草稿箱
# 标题: 从卖芯片到卖土地、跑赢博尔特：AI正在变硬

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
COVER_IMAGE="/Users/luzheqi/WorkBuddy/每日AI推文任务/generated-images/深色科技风微信公众号封面图_16_9横版比例_画面中央是一台_2026-08-18T00-57-56.png"
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
/Users/luzheqi/.workbuddy/binaries/python/versions/3.13.12/bin/python3 /Users/luzheqi/WorkBuddy/每日AI推文任务/build_draft_json.py "$THUMB_MEDIA_ID" /Users/luzheqi/WorkBuddy/每日AI推文任务/article-2026-08-18.html /tmp/draft_20260818.json "从卖芯片到卖土地、跑赢博尔特：AI正在变硬" "英伟达从卖芯片到卖土地电力；智谱GLM-5.3网安反超闭源；OpenAI多智能体告别手动选模型；宇树超人跳高2米跑赢博尔特；具身智能一周融资超20亿"

# Step 4: 创建草稿
echo "创建草稿..."
DRAFT_RESPONSE=$(create_draft "$TOKEN" "/tmp/draft_20260818.json")
DRAFT_MEDIA_ID=$(echo "$DRAFT_RESPONSE" | jq -r '.media_id')
rm -f /tmp/draft_20260818.json

if [[ "$DRAFT_MEDIA_ID" == "null" || -z "$DRAFT_MEDIA_ID" ]]; then
    echo "草稿创建失败: $DRAFT_RESPONSE"
    exit 1
fi

echo "草稿发布成功!"
echo ""
echo "文章信息"
echo "- 标题: 从卖芯片到卖土地、跑赢博尔特：AI正在变硬"
echo "- 草稿 media_id: $DRAFT_MEDIA_ID"
echo ""
echo "前往公众号后台查看并发布:"
echo "   https://mp.weixin.qq.com (登录后点击内容管理 -> 草稿箱)"
