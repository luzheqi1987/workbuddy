#!/usr/bin/env python3
"""把公众号文章中的半角标点批量转为全角标点(只处理HTML文本节点)"""
import re
import sys
from bs4 import BeautifulSoup, NavigableString

PLACEHOLDER = '\x00DOT\x00'

def fix_punct(text: str) -> str:
    mapping = [
        (',', '，'),
        (':', '：'),
        (';', '；'),
        ('?', '？'),
        ('!', '！'),
        ('(', '（'),
        (')', '）'),
    ]
    for src, dst in mapping:
        text = text.replace(src, dst)
    if '"' in text:
        parts = text.split('"')
        rebuilt = parts[0]
        for i in range(1, len(parts)):
            if i % 2 == 1:
                rebuilt += '\u201c' + parts[i]
            else:
                rebuilt += '\u201d' + parts[i]
        text = rebuilt
    if "'" in text:
        parts = text.split("'")
        rebuilt = parts[0]
        for i in range(1, len(parts)):
            if i % 2 == 1:
                rebuilt += '\u2018' + parts[i]
            else:
                rebuilt += '\u2019' + parts[i]
        text = rebuilt
    return text

def process(path):
    with open(path, 'r', encoding='utf-8') as f:
        html = f.read()
    # 保护数字小数点
    html_protected = re.sub(r'(?<=[\d])\.(?=[\d])', PLACEHOLDER, html)
    soup = BeautifulSoup(html_protected, 'html.parser')
    for node in list(soup.find_all(string=True)):
        if not isinstance(node, NavigableString):
            continue
        raw = str(node)
        if not raw.strip():
            continue
        fixed = fix_punct(raw)
        if fixed != raw:
            node.replace_with(fixed)
    out = str(soup).replace(PLACEHOLDER, '.')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(out)
    print(f'已处理: {path}')

if __name__ == '__main__':
    for p in sys.argv[1:]:
        process(p)