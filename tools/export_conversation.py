#!/usr/bin/env python3
"""把 WorkBuddy 会话 jsonl 导出成可读的 Markdown 对话纪要。

用途：会话记录存在本机 ~/.workbuddy/projects/<项目>/<sessionId>.jsonl，
不随 git 同步。导出成 md 后纳入版本控制，换电脑也能读回完整讨论脉络。

用法：
    python3 tools/export_conversation.py <会话.jsonl> <输出.md>
"""
import json
import re
import sys
from datetime import datetime

# 需要剥离的注入块：系统提醒、上下文附加数据、环境信息
STRIP_BLOCKS = [
    re.compile(r"<system-reminder\b[^>]*>.*?</system-reminder>", re.S),
    re.compile(r"<additional-data\b[^>]*>.*?</additional-data>", re.S),
    re.compile(r"<environment_details\b[^>]*>.*?</environment_details>", re.S),
]
TAG_ONLY = re.compile(r"</?(?:user_query|craft_mode|current_time|user_info)\b[^>]*>")


def clean(text: str) -> str:
    for pat in STRIP_BLOCKS:
        text = pat.sub("", text)
    text = TAG_ONLY.sub("", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def text_of(content) -> str:
    """从 str 或 content 块数组里取出纯文本。"""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for b in content:
            if not isinstance(b, dict):
                continue
            # assistant 用 output_text，user 用 input_text
            if b.get("type") in ("output_text", "input_text", "text"):
                parts.append(b.get("text") or b.get("content") or "")
        return "\n".join(p for p in parts if p)
    return ""


def parse_ts(ts):
    """兼容毫秒时间戳与 ISO 字符串两种格式。"""
    if isinstance(ts, (int, float)) or (isinstance(ts, str) and ts.isdigit()):
        return datetime.fromtimestamp(int(ts) / 1000)
    try:
        return datetime.fromisoformat(str(ts).replace("Z", "+00:00")).astimezone()
    except (ValueError, TypeError):
        return None


def main(src: str, dst: str) -> None:
    rows = []
    with open(src, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
            except json.JSONDecodeError:
                continue
            if d.get("type") != "message":
                continue
            role = d.get("role")
            if role not in ("user", "assistant"):
                continue
            body = clean(text_of(d.get("content")))
            if not body:
                continue
            ts = d.get("timestamp")
            dt = parse_ts(ts)
            rows.append((dt, role, body))

    rows.sort(key=lambda r: (r[0] is None, r[0]))
    rounds = sum(1 for r in rows if r[1] == "user")
    span = ""
    if rows and rows[0][0] and rows[-1][0]:
        span = f"{rows[0][0]:%Y-%m-%d %H:%M} ~ {rows[-1][0]:%Y-%m-%d %H:%M}"

    out = [
        "# 对话纪要",
        "",
        f"> 导出自 `{src.split('/')[-1]}`，共 {rounds} 轮提问、{len(rows)} 条消息"
        + (f"，时间跨度 {span}" if span else ""),
        "> 已剥离系统提示与工具调用细节，仅保留对话正文。",
        "",
    ]
    last_day = None
    for dt, role, body in rows:
        day = dt.strftime("%Y-%m-%d") if dt else "未知日期"
        if day != last_day:
            out += [f"## {day}", ""]
            last_day = day
        stamp = dt.strftime("%H:%M") if dt else "--:--"
        who = "用户" if role == "user" else "助手"
        out += [f"### {stamp} · {who}", "", body, ""]

    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"已导出 {len(rows)} 条消息（{rounds} 轮提问）-> {dst}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("用法: python3 export_conversation.py <会话.jsonl> <输出.md>")
    main(sys.argv[1], sys.argv[2])
