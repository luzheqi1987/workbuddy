#!/usr/bin/env python3
import json
import sys
import os

# Support: python build_draft_json.py <thumb_media_id> <html_file> <output_json> [title] [digest]
thumb_media_id = sys.argv[1]
html_file = sys.argv[2]
output_json = sys.argv[3]
title = sys.argv[4] if len(sys.argv) > 4 else "AI 前线日报 | 2026.07.18"
author = os.environ.get("WECHAT_AUTHOR", "AI日报")
digest = sys.argv[5] if len(sys.argv) > 5 else "WAIC 2026 开幕、全球 AI 合作组织成立、国产算力集体亮相、具身智能进入部署态元年"

with open(html_file, 'r', encoding='utf-8') as f:
    content = f.read()

draft = {
    "articles": [{
        "title": title,
        "author": author,
        "digest": digest,
        "content": content,
        "thumb_media_id": thumb_media_id,
        "need_open_comment": 1,
        "only_fans_can_comment": 0
    }]
}

with open(output_json, 'w', encoding='utf-8') as f:
    json.dump(draft, f, ensure_ascii=False)

# Verify byte length of title
title_bytes = len(title.encode('utf-8'))
print(f"Title: {title}")
print(f"Title bytes: {title_bytes} (limit: 64)")
print(f"Author: {author}")
print(f"Digest: {digest}")
print(f"JSON written to: {output_json}")
