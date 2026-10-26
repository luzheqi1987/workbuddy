#!/usr/bin/env python3
"""Convert markdown article to WeChat Official Account compatible HTML with inline styles."""

import re
import sys

def md_to_wechat_html(md_content):
    """Convert markdown to WeChat-compatible HTML with inline styles."""
    lines = md_content.split('\n')
    html_parts = []
    html_parts.append('<section style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', \'PingFang SC\', \'Hiragino Sans GB\', \'Microsoft YaHei\', sans-serif; line-height: 1.8; color: #333; padding: 15px; max-width: 680px; margin: 0 auto; font-size: 16px;">')
    
    in_blockquote = False
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # Skip horizontal rules
        if line.strip() == '---':
            i += 1
            continue
        
        # H1 title
        if line.startswith('# ') and not line.startswith('## '):
            title_text = line[2:].strip()
            html_parts.append(f'<h1 style="font-size: 22px; font-weight: 700; color: #1a1a1a; text-align: center; margin: 30px 0 20px; line-height: 1.4;">{title_text}</h1>')
            i += 1
            continue
        
        # H2 subheading
        if line.startswith('## '):
            sub_text = line[3:].strip()
            html_parts.append(f'<h2 style="font-size: 19px; font-weight: 700; color: #1a1a1a; margin: 35px 0 15px; padding-bottom: 10px; border-bottom: 2px solid #e8e8e8; line-height: 1.4;">{sub_text}</h2>')
            i += 1
            continue
        
        # Blockquote
        if line.strip().startswith('> '):
            if not in_blockquote:
                html_parts.append('<blockquote style="background: #f7f8fa; border-left: 4px solid #c0c4cc; padding: 15px 20px; margin: 20px 0; color: #555; font-size: 15px; border-radius: 0 4px 4px 0;">')
                in_blockquote = True
            quote_text = line.strip()[2:]
            html_parts.append(f'<p style="margin: 0 0 8px;">{quote_text}</p>')
            i += 1
            # Check if next line is also a blockquote
            continue
        elif in_blockquote and not line.strip().startswith('> '):
            html_parts.append('</blockquote>')
            in_blockquote = False
            # Don't increment i, process this line again
            continue
        
        # Empty line
        if not line.strip():
            if in_blockquote:
                html_parts.append('</blockquote>')
                in_blockquote = False
            i += 1
            continue
        
        # Bold text patterns
        line = re.sub(r'\*\*(.+?)\*\*', r'<strong style="font-weight: 700; color: #1a1a1a;">\1</strong>', line)
        
        # Normal paragraph
        html_parts.append(f'<p style="margin: 0 0 18px; text-align: justify; word-break: break-all;">{line.strip()}</p>')
        i += 1
    
    # Close any remaining blockquote
    if in_blockquote:
        html_parts.append('</blockquote>')
    
    html_parts.append('</section>')
    return '\n'.join(html_parts)


if __name__ == '__main__':
    md_file = sys.argv[1]
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    html = md_to_wechat_html(md_content)
    
    out_file = sys.argv[2] if len(sys.argv) > 2 else md_file.replace('.md', '.html')
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(html)
    
    print(f"Converted {md_file} -> {out_file}")
