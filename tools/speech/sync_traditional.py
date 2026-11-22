#!/usr/bin/env python3
"""Regenerate scripts/languages/chinese_t.po from chinese_s.po in everyday Taiwan usage.

Requires: pip install opencc-python-reimplemented
"""
import re
import sys
from pathlib import Path

from opencc import OpenCC

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "scripts/languages/chinese_s.po"
TARGET = ROOT / "scripts/languages/chinese_t.po"

# Applied to the Simplified text in order, so longer phrases must come first.
TAIWAN_PHRASES = [
    # Food and everyday objects
    ("土豆", "马铃薯"),
    ("胡萝卜", "红萝卜"),
    ("午饭", "午餐"),
    ("晚饭", "晚餐"),
    ("早饭", "早餐"),
    ("意面", "义大利麵"),
    ("卷心菜", "高丽菜"),
    ("麦芬", "马芬"),
    ("华夫饼", "鬆饼"),
    ("塑料", "塑胶"),
    ("自行车", "脚踏车"),
    ("校服", "制服"),
    ("马甲", "背心"),
    ("游园会", "园游会"),
    ("信息", "讯息"),
    ("模块", "模组"),
    ("超纲", "超出范围"),
    # Duration: Taiwan says 一下 where the mainland says 一会
    ("少走一会路", "少走一点路"),
    ("消磨一会", "消磨一下时间"),
    ("过会再试", "等一下再试"),
    ("过会回来", "晚点回来"),
    ("歇一会儿", "休息一下"),
    ("歇一会", "休息一下"),
    ("歇会", "休息一下"),
    ("等会", "等一下"),
    ("睡会", "睡一下"),
    ("一会儿", "一下"),
    ("一会", "一下"),
    # Sleepiness only; 被困 and 困难 stay as they are
    ("犯困", "想睡"),
    ("不困", "不想睡"),
    ("开始困", "开始想睡"),
    ("就困", "就想睡"),
    # Colloquial phrasing
    ("还行", "还可以"),
    ("就行了", "就可以了"),
    ("就行", "就好"),
    ("也行", "也可以"),
    ("行吧", "好吧"),
    ("费劲", "费力"),
    ("费事", "麻烦"),
    ("凑合", "将就"),
    ("赶紧", "赶快"),
    ("劳驾，请", "麻烦您"),
    ("行，那我就", "好，那我就"),
    ("纪律委员", "风纪股长"),
    ("安保", "保全"),
    ("金枪鱼", "鲔鱼"),
    ("粘在", "黏在"),
    ("拿铁咯", "拿铁啰"),
    ("打盹", "打瞌睡"),
    ("这玩意儿", "这东西"),
    ("啥", "什么"),
    ("这儿", "这里"),
    ("那儿", "那里"),
    ("哪儿", "哪里"),
    ("扔", "丢"),
    ("歇", "休息"),
    ("哦", "喔"),
]

TAIWAN_PATTERNS = [
    (re.compile(r"倒挺"), "倒是蛮"),
    (re.compile(r"挺(?![直身住拔])"), "蛮"),
    (re.compile(r"(闻|吃|摸|尝|穿)着(?=[蛮还有很像不就倒真，。])"), r"\1起来"),
    (re.compile(r"(看|听)着(?=[蛮还有很像快倒真])"), r"\1起来"),
]

# Applied after conversion: official game names and characters OpenCC leaves in a mainland form.
TRADITIONAL_FIXES = [
    ("切斯特", "賈斯特"),
    ("溫迪", "溫蒂"),
    ("揹包", "背包"),
    ("榴蓮", "榴槤"),
    ("惡心", "噁心"),
    ("錘子", "槌子"),
    ("傢俱", "家具"),
    ("意大利", "義大利"),
    ("數據", "資料"),
    ("沒法", "沒辦法"),
    ("搞", "弄"),
    ("呆在", "待在"),
    ("呆得", "待得"),
    # OpenCC picks the wrong character for these
    ("溼", "濕"),
    ("海里", "海裡"),
    ("里面", "裡面"),
    ("燬", "毀"),
    ("瞭解", "了解"),
    ("明瞭", "明了"),
    ("臺", "台"),
    ("本壘打", "全壘打"),
    ("捱罵", "挨罵"),
    ("不是我乾的", "不是我幹的"),
    ("鍊鋼", "煉鋼"),
    ("課本里", "課本裡"),
    ("遺蹟", "遺跡"),
    ("巖柱", "岩柱"),
    ("佈滿", "布滿"),
    ("幹淨", "乾淨"),
    ("幹木頭", "乾木頭"),
    ("變幹", "變乾"),
    ("才會幹", "才會乾"),
    ("花幹了", "花乾了"),
    ("又幹又脆", "又乾又脆"),
    ("有點幹", "有點乾"),
    ("已經幹了", "已經乾了"),
    ("肉幹不了", "肉乾不了"),
    ("還沒幹", "還沒乾"),
    ("可幹不了", "可乾不了"),
    ("幹好了", "乾好了"),
    ("也幹了", "也乾了"),
    ("幹掉了", "乾掉了"),
    ("幹得讓人放心", "乾得讓人放心"),
    ("又幹又有", "又乾又有"),
    ("這麼幹嗎", "這麼乾嗎"),
    ("這只不", "這隻不"),
    ("好幾只", "好幾隻"),
    ("那幾只", "那幾隻"),
    # Taiwan quotation marks
    ("“", "「"),
    ("”", "」"),
]


def localize(converter, text):
    for simplified, taiwan in TAIWAN_PHRASES:
        text = text.replace(simplified, taiwan)
    for pattern, taiwan in TAIWAN_PATTERNS:
        text = pattern.sub(taiwan, text)
    text = converter.convert(text)
    for wrong, right in TRADITIONAL_FIXES:
        text = text.replace(wrong, right)
    return text


def main():
    converter = OpenCC("s2tw")
    source = SOURCE.read_text(encoding="utf-8")
    header_end = source.index("\n\n") + 2
    header = source[:header_end].replace("Language: zh-CN", "Language: zh-TW")
    body = "\n".join(
        'msgstr "' + localize(converter, line[8:-1]) + '"' if line.startswith('msgstr "') else line
        for line in source[header_end:].split("\n")
    )
    TARGET.write_text(header + body, encoding="utf-8", newline="\n")
    print(f"Wrote {TARGET.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
