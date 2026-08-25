#!/usr/bin/env python3
# r63-b 逐字校验：重构前后所有 schema 数据行（ItemSchema/ItemProperty/std 行）必须逐一相等
before = open("/tmp/r63b_before.swift", encoding="utf-8").read()
after = open("LyricsMTMR/MTMR/Preferences/Editor/EditorSchema.swift", encoding="utf-8").read()

def schema_lines(t):
    out = []
    for l in t.splitlines():
        s = l.strip()
        if s.startswith(("ItemSchema(type:", "ItemProperty(key:", "], width:", "std(width:")):
            out.append(s)
    return out

b, a = schema_lines(before), schema_lines(after)
print("schema-line counts: before=%d after=%d identical=%s" % (len(b), len(a), b == a))
if b != a:
    for i, (x, y) in enumerate(zip(b, a)):
        if x != y:
            print("first diff at index", i)
            print("B:", x)
            print("A:", y)
            break
    print("lens", len(b), len(a))
else:
    # 再校验类型顺序（拼接顺序=原数组顺序）与 ItemProperty key 顺序
    import re
    def types_of(lines_list):
        res = []
        for l in lines_list:
            if l.startswith("ItemSchema(type:"):
                m = re.search(r'type: "([^"]+)"', l)
                if m:
                    res.append(m.group(1))
        return res
    tb, ta = types_of(b), types_of(a)
    print("type order identical:", tb == ta, "| n =", len(tb), "| first:", tb[0] if tb else None, "| last:", tb[-1] if tb else None)
    kb = [re.search(r'key: "([^"]+)"', l).group(1) for l in b if l.startswith("ItemProperty(key:")]
    ka = [re.search(r'key: "([^"]+)"', l).group(1) for l in a if l.startswith("ItemProperty(key:")]
    print("property key sequence identical:", kb == ka)
