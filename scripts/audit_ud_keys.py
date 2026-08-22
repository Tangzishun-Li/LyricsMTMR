#!/usr/bin/env python3
"""R57 A卡审计辅助：枚举 AppSettings @UserDefault 属性，逐键 grep 全仓读写点。"""
import re, os, json, subprocess

ROOT = "/Users/litz/codespace/MTMR with LyricsX/.worktrees/t_6c013627/LyricsMTMR"
SRC = os.path.join(ROOT, "MTMR")
src = open(os.path.join(SRC, "App/AppSettings.swift")).read()
lines = src.split("\n")

props = []
for i, l in enumerate(lines):
    m = re.search(r'@UserDefault\(key:\s*"([^"]+)",\s*defaultValue:', l)
    if m:
        for j in range(i + 1, min(i + 4, len(lines))):
            m2 = re.search(r'static var (\w+)', lines[j])
            if m2:
                props.append({"prop": m2.group(1), "key": m.group(1), "line": j + 1})
                break

print(f"total @UserDefault props: {len(props)}")
report = []
for p in props:
    prop = p["prop"]
    # grep for usages of the property name across MTMR source (excluding definition line)
    out = subprocess.run(
        ["grep", "-rn", "--include=*.swift", r"\b" + prop + r"\b", SRC],
        capture_output=True, text=True)
    hits = []
    for h in out.stdout.splitlines():
        path, lineno, rest = h.split(":", 2)
        rel = os.path.relpath(path, ROOT)
        # skip the definition itself in AppSettings.swift
        if rel.endswith("App/AppSettings.swift") and (int(lineno) == p["line"] or f"static var {prop}" in rest):
            continue
        hits.append(f"{rel}:{lineno}: {rest.strip()[:120]}")
    reads = [h for h in hits if not re.search(r"=\s*[\w\.\"\'\(\)\[\]]+\s*$", h.split(": ", 1)[1] if ": " in h else "")]
    report.append({"prop": prop, "key": p["key"], "defLine": p["line"], "hits": hits})
    print(f"\n=== {prop} ({p['key']}) — {len(hits)} usage(s) outside definition ===")
    for h in hits[:20]:
        print("  " + h)

json.dump(report, open("/tmp/ud_audit_raw.json", "w"), ensure_ascii=False, indent=1)
print("\nsaved /tmp/ud_audit_raw.json")
