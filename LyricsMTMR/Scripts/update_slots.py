#!/usr/bin/env python3
"""Extend theme4/theme5 themeSwitch to labels 1-15 and register slots 6-15.
theme1/2/3 are NEVER modified. theme4/theme5 only get their themes[] extended.
"""
import json, os, re

OUT = os.path.expanduser("~/Library/Application Support/LyricsMTMR")

def themes_block():
    lines = ['    "themes": [']
    for i in range(1, 16):
        lines.append('      {')
        lines.append('        "label": "%d",' % i)
        lines.append('        "preset": "theme%d.json"' % i)
        if i < 15:
            lines.append('      },')
        else:
            lines.append('      }')
    lines.append('    ]')
    return "\n".join(lines)

pat = re.compile(r'"themes":\s*\[.*?\]', re.DOTALL)
for fname in ("theme4.json", "theme5.json"):
    path = os.path.join(OUT, fname)
    with open(path, encoding="utf-8") as f:
        text = f.read()
    text2, n = pat.subn(lambda m: themes_block(), text, count=1)
    assert n == 1, fname + ": expected 1 themes array, got " + str(n)
    json.loads(text2)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text2)
    print(fname + ": themes extended to 1-15")

si_path = os.path.join(OUT, "slot-index.json")
with open(si_path, encoding="utf-8") as f:
    si = json.load(f)

NAMES = {6:"开发者",7:"极客",8:"工具箱",9:"生活",10:"健康",11:"办公",12:"校园",13:"财务运维",14:"系统监控",15:"创意"}
existing = set(s["id"] for s in si["slots"])
for i in range(6, 16):
    sid = "theme%d" % i
    if sid in existing:
        continue
    si["slots"].append({
        "fileName": "../theme%d.json" % i,
        "isActive": False,
        "id": sid,
        "name": "theme%d (%s)" % (i, NAMES[i]),
        "shortcut": str(i),
    })
with open(si_path, "w", encoding="utf-8") as f:
    json.dump(si, f, ensure_ascii=False, separators=(",", ":"))
print("slot-index.json: %d slots total" % len(si["slots"]))
print("done")
