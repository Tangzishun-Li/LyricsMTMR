#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""第 35 轮 A 卡程序化等价性实证：注册表闭包 vs switch 分支逐语句比对。

提取 ItemsParsing.swift 中第 35 轮第六批（收官批）迁移的 9 个注册表闭包体与对应
switch 分支体，逐语句 diff（末行 `return`/`self =` 前缀归一后比对，
中间语句逐字节比对）。输出 `OK: 9/9 类型注册表闭包与 switch 分支逐行等价`
或逐类型 FAIL 明细。退出码 0=全部等价。

用法：python3 tools/verify_round35_equiv.py
"""
import re
import sys

SRC = "LyricsMTMR/MTMR/Core/ItemsParsing.swift"

# 第 35 轮第六批（收官批）迁移 9 类型（形态 A 全部），与报告迁移清单一致；
# base64Tool 保持未迁（switch 回退路径测试锚点），不在本批
BATCH = [
    "pixelPet", "homekitScene", "aiSelectedText", "rssUnread",
    "citationGen", "paperProgress", "paperTags", "bilibiliFeed", "apiTester",
]

lines = open(SRC, encoding="utf-8").read().splitlines()


def extract_closure_bodies():
    """在注册表字典区域内提取 {key: 闭包体行列表}。"""
    reg_start = next(i for i, ln in enumerate(lines) if "static let registeredTypeDecoders" in ln)
    reg_end = next(i for i in range(reg_start, len(lines)) if lines[i].strip() == "]")
    bodies = {}
    i = reg_start
    while i <= reg_end:
        m = re.match(r"^\s*\.(\w+): \{", lines[i])
        if m and m.group(1) in BATCH:
            key = m.group(1)
            body = []
            i += 1
            while i <= reg_end and not lines[i].strip().startswith("},"):
                body.append(lines[i])
                i += 1
            assert lines[i].strip().startswith("},"), f"{key} 闭包未以 }} 结尾"
            bodies[key] = body
        i += 1
    return bodies


def extract_switch_bodies():
    """在 decode switch 区域内提取 {key: 分支体行列表}。"""
    sw_start = next(i for i, ln in enumerate(lines) if "switch type {" in ln and "ItemsParsing" not in ln)
    sw_end = None
    for i in range(sw_start + 1, len(lines)):
        if lines[i] == "        }":
            sw_end = i
            break
    assert sw_end is not None, "decode switch 闭合未找到"
    bodies = {}
    i = sw_start + 1
    while i < sw_end:
        m = re.match(r"^\s*case \.(\w+):", lines[i])
        if m and m.group(1) in BATCH:
            key = m.group(1)
            body = []
            i += 1
            while i < sw_end and not re.match(r"^\s*case \.", lines[i]):
                body.append(lines[i])
                i += 1
            bodies[key] = body
        else:
            i += 1
    return bodies


def normalize(body):
    """去首尾空白；末行 `return` → `self =` 归一（闭包与 switch 仅此一处差异）。"""
    out = [ln.strip() for ln in body]
    for idx in range(len(out) - 1, -1, -1):
        if out[idx]:
            if out[idx].startswith("return "):
                out[idx] = "self = " + out[idx][len("return "):]
            break
    return out


def main():
    closures = extract_closure_bodies()
    switches = extract_switch_bodies()
    missing_c = [k for k in BATCH if k not in closures]
    missing_s = [k for k in BATCH if k not in switches]
    assert not missing_c, f"注册表缺失闭包: {missing_c}"
    assert not missing_s, f"switch 缺失分支: {missing_s}"

    results = []
    for key in BATCH:
        c, s = normalize(closures[key]), normalize(switches[key])
        ok = c == s
        results.append((key, ok, "逐行等价" if ok else f"闭包 {c} ≠ switch {s}"))

    fails = [r for r in results if not r[1]]
    for key, ok, detail in results:
        print(f"[{'OK ' if ok else 'FAIL'}] {key} — {detail}")
    print(f"\nOK: {len(results) - len(fails)}/{len(results)} 类型注册表闭包与 switch 分支逐行等价")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main())
