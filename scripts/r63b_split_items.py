#!/usr/bin/env python3
# r63-b: EditorSchema items 巨表达式 → 21 个分区显式类型分段构造函数。
# 机械搬运：分区行原样移动，除缩进(8→8 保持)与函数包装外零字面改动。
import re, sys

SRC = "/Users/litz/codespace/MTMR with LyricsX/.worktrees/t_0674e8f9/LyricsMTMR/MTMR/Preferences/Editor/EditorSchema.swift"
lines = open(SRC, encoding="utf-8").read().splitlines(keepends=False)

# 1-based 行号定位（先核对锚点；173 行 = items 声明，174 行 = "// Basic"）
assert lines[172].strip() == "private static let items: [String: ItemSchema] = build([", lines[172]
assert lines[173].strip() == "// Basic", lines[173]
assert lines[559].strip() == "])", lines[559]

# 分区注释行（1-based）
section_starts = [174, 218, 235, 257, 287, 308, 328, 343, 362, 374, 385, 411, 435, 456, 477, 492, 511, 519, 536, 549, 556]  # 21 sections
names = ["basic", "media", "system", "info", "extra", "musicPlus", "special", "dev", "geek", "tools",
         "life", "health", "office", "campus", "finance", "ops", "systemPlus", "creative", "academic", "geekPlus", "creativePlus"]
assert len(section_starts) == len(names) == 21

# 每个分区的行范围（含尾部空行分隔）：start..next_start-1；最后分区到 559-1（不含 `])`）
ranges = []
for i, st in enumerate(section_starts):
    end = (section_starts[i + 1] - 1) if i < 20 else 558  # 1-based inclusive; 556 区止于 558(bilibiliFeed `], width...))`), 559 是 `])`
    ranges.append((st, end))

# 提取各分区正文行并规整缩进：原 8 空格基准 → 函数体内 8 空格（保持不变）
sections_code = []
for (st, end) in ranges:
    body = lines[st - 1 : end]  # list of str
    # 去掉尾部空行（分区之间原本的空行）
    while body and body[-1].strip() == "":
        body.pop()
    # 头部不应有空行
    while body and body[0].strip() == "":
        body.pop(0)
    sections_code.append(body)

def snake_to_camel(s):
    return s[0].upper() + s[1:]

out = []
out.extend(lines[:172])  # 保留到 1-based 172 行（0..171），去掉 173 行的 items 声明

# 为每个分区生成函数
for name, body in zip(names, sections_code):
    out.append("")
    out.append("    /// Schema registry part %s — 原单巨表达式按 palette 分区拆分的编译期减负段。" % name)
    out.append("    /// 行内容自 r62 收口版逐字搬运，运行时语义零变化（顺序=拼接顺序）。")
    out.append("    private static func part%s() -> [ItemSchema] {" % snake_to_camel(name))
    out.append("        return [")
    for l in body:
        out.append(l)
    out.append("        ]")
    out.append("    }")

# 新的 items 聚合声明
out.append("")
out.append("    /// 全量注册表：按分区顺序聚合（原 build([...]) 单巨表达式等价改写）。")
out.append("    private static let items: [String: ItemSchema] = build(")
out.append("        partBasic()")
for name in names[1:]:
    out.append("            + part%s()" % snake_to_camel(name))
out.append("    )")

# 尾部：原 559 行是 `])`，560 空行起为 Fallback 段——1-based 560 起
tail = lines[559:]  # 0-based 559 = 1-based 560
out.extend(tail)

new_content = "\n".join(out).rstrip("\n") + "\n"
open(SRC, "w", encoding="utf-8").write(new_content)
print("rewritten OK")
print("new line count:", new_content.count("\n"))
