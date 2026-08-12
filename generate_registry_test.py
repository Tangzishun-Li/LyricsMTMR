#!/usr/bin/env python3
"""Round 25-A: generate RegistryReconciliationTests.swift from source truth.

Extracts the 98 ItemTypeRaw case names (ItemsParsing.swift) and the 98
identifierBase mappings (TouchBarController.swift) directly from the code,
then emits the canonical fixture + reconciliation tests. Regenerate whenever
the fixture needs refreshing; the generated file is committed as-is.
"""
import re, pathlib

ROOT = pathlib.Path("/Users/litz/codespace/MTMR with LyricsX /.worktrees/round25-A/LyricsMTMR/MTMR")

parsing = (ROOT / "Core" / "ItemsParsing.swift").read_text()
controller = (ROOT / "Core" / "TouchBarController.swift").read_text()

# --- 1. ItemTypeRaw case names ---
raw_block = re.search(r"enum ItemTypeRaw: String, Decodable, CaseIterable \{(.*?)\n    \}", parsing, re.S).group(1)
raw_names = re.findall(r"^\s{8}case (\w+)$", raw_block, re.M)
assert len(raw_names) == 98, f"expected 98 ItemTypeRaw cases, got {len(raw_names)}"

# --- 2. identifierBase mapping (case -> return value) ---
idb_block = re.search(r"var identifierBase: String \{(.*?)\n    \}\n\}", controller, re.S).group(1)
pairs = []
for m in re.finditer(r"case \.(\w+)(?:\([^)]*\))?:\n\s+return (\"[^\"]*\"|[A-Za-z]+\.identifier)", idb_block):
    name, ret = m.group(1), m.group(2)
    if ret.endswith(".identifier"):
        # constant-backed mappings (pomodoro/network/darkMode)
        const = ret.split(".")[0]
        const_val = None
        for f in (ROOT / "Widgets").rglob("*.swift"):
            t = f.read_text()
            const_val = re.search(rf"class {const}[\s\S]*?static (?:let|var) identifier(?:: String)? = \"([^\"]+)\"", t, re.S)
            if const_val:
                break
        assert const_val, f"constant {const} not found"
        pairs.append((name, const_val.group(1)))
    else:
        pairs.append((name, ret.strip('"')))
assert len(pairs) == 98, f"expected 98 identifierBase cases, got {len(pairs)}"
assert [n for n, _ in pairs] == raw_names, "identifierBase order != ItemTypeRaw order"

# --- 3. minimal decodable JSON per type ---
REQUIRED_FIELDS = {
    "staticButton": '{"type": "staticButton", "title": "t"}',
    "appleScriptTitledButton": '{"type": "appleScriptTitledButton", "source": {}}',
    "shellScriptTitledButton": '{"type": "shellScriptTitledButton", "source": {}}',
    "swipe": '{"type": "swipe", "direction": "left", "fingers": 2}',
    "group": '{"type": "group", "items": []}',
    "expandable": '{"type": "expandable", "items": []}',
}
def json_for(name):
    return REQUIRED_FIELDS.get(name, '{"type": "%s"}' % name)

# --- 4. registry-only keys ---
PREDEFINED_14 = ["escape", "delete", "brightnessUp", "brightnessDown",
                 "illuminationUp", "illuminationDown", "volumeDown", "volumeUp",
                 "mute", "previous", "play", "next", "sleep", "displaySleep"]
CONTROLLER_2 = ["exitTouchbar", "close"]
registry_only = PREDEFINED_14 + CONTROLLER_2
assert len(registry_only) == 16
assert not (set(raw_names) & set(registry_only)), "enum/registry overlap unexpected"

lines = ['    private let canonicalItems: [CanonicalEntry] = [']
for name, idb in pairs:
    escaped_json = json_for(name).replace('"', '\\"')
    lines.append(f'        CanonicalEntry(name: "{name}", json: "{escaped_json}", identifierBase: "{idb}"),')
lines.append('    ]')
fixture = "\n".join(lines)

out = f'''//
//  RegistryReconciliationTests.swift
//  LyricsMTMRTests
//
//  Round 25 (A): 注册表混合架构对账测试 — ItemType 枚举 ↔ 注册表 ↔
//  BarItemFactory ↔ identifierBase ↔ 114 路径的代码级持续保障。
//
//  机制：本文件持有一份「规范清单」（canonicalItems，98 条，由
//  ItemsParsing.swift ItemTypeRaw 与 TouchBarController.swift identifierBase
//  逐条提取生成）——它是测试侧的唯一基准。五处注册点任何一处
//  新增/删除/漏注册/改名，都会至少有一个断言失败：
//    L1  ItemTypeRaw 枚举全集        ↔ 规范清单        （CaseIterable 枚举）
//    L2  解码 switch（type → ItemType）↔ 规范清单        （最小 JSON 全量解码）
//    L3  identifierBase switch       ↔ 规范清单        （逐条期望值）
//    L4  BarItemFactory 创建 switch  ↔ 规范清单        （全量真实构造）
//    L5  SupportedTypesHolder 注册表 ↔ 规范清单 16 键   （键集精确对账）
//  114 路径口径 = ItemTypeRaw 98 + 注册表预定义 14 + 控制器注册 2；
//  themeSwitch 为枚举/注册表重复注册（文档口径不计）。
//  运行方式：hosted（TEST_HOST），widget 类在 app 模块内。
//
//  覆盖边界（诚实声明）：
//  - Swift switch 分支无法反射：L2/L3/L4 通过「全量解码 + 全量构造 +
//    逐条 identifierBase 期望值」的等价取证替代分支计数；编译期穷尽性
//    （decode/identifierBase/BarItemFactory 三处 switch 对 ItemTypeRaw/ItemType
//    的 exhaustive 检查）已保证「新增 case 漏改 switch」直接编译失败。
//  - noiseMeter 构造期间临时置全局隐藏态：round-24 采集暂停门使 init
//    跳过真实麦克风启动（AVAudioEngine/TCC），defer 恢复。
//
import XCTest
@testable import LyricsMTMR

class RegistryReconciliationTests: XCTestCase {{

    private let identifier = NSTouchBarItem.Identifier("registry.reconciliation")

    /// 规范条目：name = JSON type 字段 / ItemTypeRaw rawValue；
    /// json = 该类型最小合法配置；identifierBase = identifierBase switch 期望值。
    private struct CanonicalEntry {{
        let name: String
        let json: String
        let identifierBase: String
    }}

    /// 唯一基准清单（98 条，生成自源码，勿手改）。
{fixture}

    /// 注册表专属键：14 预定义 + 2 控制器注册；与枚举无交集，
    /// themeSwitch 为唯一重复注册键（在枚举侧）。
    private let registryOnlyKeys: [String] = [
        "escape", "delete", "brightnessUp", "brightnessDown",
        "illuminationUp", "illuminationDown", "volumeDown", "volumeUp",
        "mute", "previous", "play", "next", "sleep", "displaySleep",
        "exitTouchbar", "close",
    ]

    private var canonicalNames: [String] {{ canonicalItems.map {{ $0.name }} }}

    // MARK: - 帮助函数

    private func decodeFirst(_ entry: CanonicalEntry) -> BarItemDefinition? {{
        decodeFirst(name: entry.name, json: entry.json)
    }}

    private func decodeFirst(name: String, json: String) -> BarItemDefinition? {{
        guard let defs = Data("[\(json)]".utf8).barItemDefinitions(), let def = defs.first else {{
            XCTFail("\\(name): 最小 JSON 解码失败 — \\(json)")
            return nil
        }}
        return def
    }}

    private func makeItem(for entry: CanonicalEntry, factory: BarItemFactory) throws -> NSTouchBarItem? {{
        guard let def = decodeFirst(entry) else {{ return nil }}
        if entry.name == "noiseMeter" {{
            // 隐藏态下 init 经 round-24 采集暂停门跳过麦克风启动，
            // 避免测试触碰真实 AVFoundation 硬件 / TCC 授权。
            TouchBarVisibilityState.shared.setBarHidden(true)
            defer {{ TouchBarVisibilityState.shared.setBarHidden(false) }}
        }}
        return try factory.createItem(forIdentifier: identifier, definition: def)
    }}

    private func makeFactory() -> BarItemFactory {{
        BarItemFactory(actionResolver: {{ _ in nil }},
                       longActionResolver: {{ _ in nil }},
                       closureResolver: {{ _ in nil }})
    }}

    // MARK: - L1: ItemTypeRaw 枚举全集 ↔ 规范清单

    func testItemTypeRawEnumMatchesCanonicalRegistry() {{
        let rawNames = ItemType.ItemTypeRaw.allCases.map {{ $0.rawValue }}
        XCTAssertEqual(rawNames.count, canonicalItems.count,
                       "ItemTypeRaw case 数与规范清单不一致（新增/删除枚举 case？）")
        XCTAssertEqual(Set(rawNames), Set(canonicalNames),
                       "ItemTypeRaw 全集与规范清单不等（改名/漏登/多登）")
        XCTAssertEqual(rawNames.sorted(), canonicalNames.sorted(),
                       "ItemTypeRaw 与规范清单存在具体差异：\\(rawNames.sorted()) vs \\(canonicalNames.sorted())")
        XCTAssertEqual(rawNames.count, 98, "ItemTypeRaw 应为 98 case（第 25 轮口径）")
    }}

    // MARK: - L2/L3: 解码 switch + identifierBase switch ↔ 规范清单

    func testCanonicalTypesDecodeToOwnIdentifierBase() {{
        for entry in canonicalItems {{
            guard let def = decodeFirst(entry) else {{ continue }}
            if case .staticButton(title: "unknown") = def.type {{
                XCTFail("\\(entry.name): 解码落入 unknown 降级（decode switch 缺分支或注册表误拦截）")
                continue
            }}
            XCTAssertEqual(def.type.identifierBase, entry.identifierBase,
                           "\\(entry.name): identifierBase 与规范清单漂移（identifierBase switch 或 decode 映射错位）")
        }}
    }}

    // MARK: - L4: BarItemFactory 创建 switch ↔ 规范清单

    func testFactoryCreatesEveryCanonicalType() throws {{
        let factory = makeFactory()
        for entry in canonicalItems {{
            let item = try makeItem(for: entry, factory: factory)
            XCTAssertNotNil(item, "\\(entry.name): BarItemFactory switch 缺分支或构造失败")
        }}
    }}

    // MARK: - L5: SupportedTypesHolder 注册表 ↔ 规范清单 16 键

    func testSupportedTypesHolderRegistryMatchesCanonical() {{
        // 触发控制器 init 的运行时注册（exitTouchbar / close / themeSwitch）
        _ = TouchBarController.shared
        let registry = Set(SupportedTypesHolder.sharedInstance.registeredTypeNames)
        let rawNames = Set(ItemType.ItemTypeRaw.allCases.map {{ $0.rawValue }})

        let overlap = registry.intersection(rawNames)
        XCTAssertEqual(overlap, Set(["themeSwitch"]),
                       "注册表与枚举的交集应仅为 themeSwitch（重复注册文档口径），实际：\\(overlap.sorted())")

        let registryOnly = registry.subtracting(rawNames)
        XCTAssertEqual(registryOnly, Set(registryOnlyKeys),
                       "注册表非枚举键应恰为 14 预定义 + exitTouchbar/close，实际：\\(registryOnly.sorted())")

        XCTAssertEqual(registry.count, 17, "注册表总键数应为 17（14 + 2 + themeSwitch）")
    }}

    func testRegistryOnlyKeysDecodeThroughPresetDecoders() {{
        _ = TouchBarController.shared
        let expectedTitles: [String: String] = [
            "escape": "esc", "delete": "del", "exitTouchbar": "exit",
            "sleep": "☕️", "displaySleep": "☕️",
        ]
        for key in registryOnlyKeys {{
            guard let def = decodeFirst(name: key, json: #"{{"type": "\#(key)"}}"#) else {{ continue }}
            guard case let .staticButton(title: title) = def.type else {{
                XCTFail("\\(key): 注册表预设应产出 staticButton（未注册将落入 unknown 降级）")
                continue
            }}
            XCTAssertEqual(title, expectedTitles[key] ?? "",
                           "\\(key): 预设标题漂移（未注册时降级标题应为 unknown）")
        }}
    }}

    // MARK: - 114 路径口径

    func testTotalPathCountIs114() {{
        XCTAssertEqual(canonicalItems.count, 98, "枚举侧 98 条")
        XCTAssertEqual(registryOnlyKeys.count, 16, "注册表侧 16 条（14 预定义 + 2 控制器）")
        XCTAssertTrue(Set(canonicalNames).isDisjoint(with: Set(registryOnlyKeys)),
                      "98 枚举键与 16 注册表键不得重叠（themeSwitch 重复注册除外）")
        XCTAssertEqual(canonicalItems.count + registryOnlyKeys.count, 114,
                       "Item 类型全集口径 114 = ItemTypeRaw 98 + 预定义 14 + 控制器 2")
        // 枚举全集与注册表全集合并不重复计数：114 个互异名字
        let allPaths = Set(canonicalNames).union(Set(registryOnlyKeys))
        XCTAssertEqual(allPaths.count, 114, "98 + 16 应合并为 114 个互异路径名")
    }}
}}
'''

out_path = ROOT.parent / "MTMRTests" / "RegistryReconciliationTests.swift"
out_path.write_text(out)
print(f"wrote {out_path} ({len(out)} bytes, {len(pairs)} entries)")
