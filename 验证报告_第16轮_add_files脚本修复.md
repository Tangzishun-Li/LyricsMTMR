# 验证报告_第16轮_add_files脚本修复

> 第 16 轮（功能/优化迭代第 4 轮）子任务 A · 工程规范 · code-agent · 分支 r16/tooling（基于 main@5d2c4fa）
> 日期：2026-08-12

## 一、结论摘要

`LyricsMTMR/Scripts/add_files.py` 锚点过期问题（遗留问题⑧）修复完成：4 处写入全部改为**结构化段内定位**，不再依赖「某文件是某列表的最后一个条目」的硬编码假设。实证通过：探针文件 `Widgets/Tools/AddFilesProbe.swift` 一键注册 → pbxproj 4 处条目（PBXBuildFile / PBXFileReference / group child / Sources phase）全部写入且落点正确 → xcodebuild build **BUILD SUCCEEDED** → 二次运行幂等（skip 输出）→ 探针与注册条目清理干净，仓库恢复基线。

- 故障根因：旧脚本 `SOURCES_ANCHOR` / `WIDGETS_CHILD_ANCHOR` 硬编码「QuickReplyBarItem.swift 是 Sources 阶段最后一个条目 / Widgets 分组最后一个 child」+ 正则 `锚点 + \);` 要求其后紧跟列表收尾；现状已过期（Sources 阶段其后有 HolidayCountdown/NetworkSpeed/GitStatus 等 C0FF* 条目；QuickReplyBarItem 实际在 Productivity 分组、其后还有 ReadTimer/ReadingProgress/StandupTimer），正则匹配不到 → **静默失败**（str.replace 不报错），只写入 BuildFile/FileRef 两段，pbxproj 半注册。
- 修复方案：① BuildFile/FileRef 两段改为插在各自 section 的 `/* End ... section */` 标记前；② group child 按 group 名**动态定位真实 PBXGroup**（匹配 `name`/`path` 属性），插在其 children 列表末尾；③ Sources 条目经 app 目标（LyricsMTMR）buildPhases 解析出**app 的** Sources phase（绝不落入单测目标），插在其 files 列表末尾。`uuids_for` 保持不变（C0FE/C0FF + sha1 前缀），幂等语义不变（ref 已存在即 skip）。
- 附加收益：group 参数从「仅 Widgets/Preferences 两个白名单」扩展为**任意组名**（Tools/Life/System/… 均可），失败从静默改为**响亮报错且不写盘**（`SystemExit`，实测未知组 exit=1 且 pbxproj 零改动）。

## 二、故障根因（旧脚本逐行分析）

旧脚本 4 个锚点：

| 锚点 | 旧假设 | 现状 | 结果 |
|:---|:---|:---|:---|
| `BUILD_ANCHOR`（QuickReplyBarItem 的 BuildFile 行） | 该行存在即可 str.replace | 行仍在（:127） | ✅ 能写入（但插入点在中段） |
| `REF_ANCHOR`（QuickReplyBarItem 的 FileRef 行） | 该行存在即可 str.replace | 行仍在（:398） | ✅ 能写入（但插入点在中段） |
| `SOURCES_ANCHOR` + 正则 `\\);` | QuickReplyBarItem 是 Sources 阶段**最后一个**条目，其后紧跟 `\t\t\t);` | :1187 之后还有 HolidayCountdown/NetworkSpeed/GitStatus 等 30+ C0FF* 条目 | ❌ 正则不匹配 → **静默失败** |
| `WIDGETS_CHILD_ANCHOR` + 正则 `\\);` | QuickReplyBarItem 是 Widgets 分组**最后一个** child，其后紧跟 `\t\t\t);` | QuickReplyBarItem 在 **Productivity** 分组（:794），其后还有 ReadTimer/ReadingProgress/StandupTimer | ❌ 正则不匹配 → **静默失败** |
| `PREFS_CHILD_ANCHOR` | — | 行仍在（:851），插入点在 Preferences 分组中段 | ✅ 能写入（非末尾，语义尚可） |

旧脚本用 `str.replace(..., count=1)` 写 BuildFile/FileRef（锚点行存在即成功），用 `re.sub` 写 group child / Sources（要求「锚点 + 收尾 `);`」整体匹配）——两类机制**错误表现不一致**：前者静默成功、后者静默失败，且全程不报错，最终 pbxproj 半注册。第 15 轮 A 卡 HolidayCountdown.swift 即因此需要手工补 2 处注册（8 处注册中 6 处靠手工）。

## 三、修复方案（结构化定位，零「末尾条目」假设）

新脚本 3 类写入全部改为**结构锚点**：

1. **PBXBuildFile / PBXFileReference 段**：定位 `/* End PBXBuildFile section */` / `/* End PBXFileReference section */` 标记（pbxproj 固有 section 边界，永不随条目增删失效），新条目插在标记之前（即段尾）。若标记缺失 → `SystemExit` 响亮失败。
2. **group child**：`find_group_children_end(text, group)` 用正则扫描全部 `isa = PBXGroup` 块，取 `name = <group>;` 或 `path = <group>;` 属性匹配的块（0 命中 / 多命中都报错），在该块 children 列表的收尾 `);` 前插入。→ **按 group 名动态定位真实末尾条目**，且支持任意组名（Widgets/Tools/Life/Preferences/…）。
3. **Sources phase**：`find_app_sources_files_end(text)` 先定位 app 目标块 `/* LyricsMTMR */`（正则精确匹配，不会误中 LyricsMTMRTests），从其 `buildPhases` 列表解析出 `/* Sources */` phase id，再定位该 phase 的 files 列表，在收尾 `);` 前插入。→ 新文件**永远进 app 目标的 Sources phase，绝不进单测目标**（旧脚本锚点恰好指向 app 的 phase，行为保持一致并更严谨）。

保持不变：`uuids_for`（C0FE/C0FF + sha1(name)[:20]）→ 确定性 UUID 幂等；`if ref in text: skip` 幂等检测；CLI 用法 `group:name`。

## 四、实证过程与结果

### 1. 探针注册（4 处条目落点验证）

```
$ python3 Scripts/add_files.py Tools:AddFilesProbe.swift
add: Tools/AddFilesProbe.swift
done
```

pbxproj 实测 4 处条目（grep AddFilesProbe）：

| # | 条目 | 落点（行号） | 验证 |
|:---|:---|:---|:---|
| 1 | PBXBuildFile `C0FFAE36… /* AddFilesProbe.swift in Sources */ = {isa = PBXBuildFile; …}` | :241，紧邻 `/* End PBXBuildFile section */` 之前 | ✅ 段尾 |
| 2 | PBXFileReference `C0FEAE36… /* AddFilesProbe.swift */ = {isa = PBXFileReference; … path = AddFilesProbe.swift; …}` | :508，紧邻 `/* End PBXFileReference section */` 之前 | ✅ 段尾 |
| 3 | group child `C0FEAE36… /* AddFilesProbe.swift */,` | :780，**Tools 分组** children 列表末尾（WordLookup.swift 之后、收尾 `);` 之前） | ✅ 真实末尾 |
| 4 | Sources phase `C0FFAE36… /* AddFilesProbe.swift in Sources */,` | :1290，**app 目标（B082B24B）** Sources phase files 列表末尾（RSSTabView.swift 之后、收尾 `);` 之前；单测目标 B082B25D 未被触及） | ✅ app phase |

落点语义核对：QuickReplyBarItem 所在 Productivity 分组、以及单测 Sources phase 均零改动 → 不再依赖过期锚点。

### 2. 构建实证

```
$ xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/LyricsMTMR-dd-r16a-build
** BUILD SUCCEEDED **
```

探针文件被编译进 app 目标，构建全绿（独立 derivedDataPath，避免污染仓库）。未触发全量回归（本轮父任务已实证 118 用例 0 失败，约束明确分支内 build 足够）。

### 3. 幂等实证（二次运行 skip）

```
$ python3 Scripts/add_files.py Tools:AddFilesProbe.swift
skip (present): AddFilesProbe.swift
nothing to do
```

pbxproj 保持 4 行新增（git diff --stat 前后一致），未重复写入 → 确定性 UUID 幂等成立。

### 4. 失败模式实证（响亮而非静默）

```
$ python3 Scripts/add_files.py NoSuchGroup:Probe2.swift
add: NoSuchGroup/Probe2.swift
group not found: NoSuchGroup     # SystemExit，exit=1
```

且 **pbxproj 零改动**（grep Probe2 = 0）→ 任何定位失败都会在写盘前中断，杜绝半注册。

### 5. 清理与恢复

```
$ rm LyricsMTMR/MTMR/Widgets/Tools/AddFilesProbe.swift
$ git checkout -- LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj
$ git status --short
 M LyricsMTMR/Scripts/add_files.py      # 仅脚本修复，仓库干净
```

## 五、变更明细

| 文件 | 改动 |
|:---|:---|
| `LyricsMTMR/Scripts/add_files.py` | 唯一生产改动：删除 5 个硬编码锚点常量（BUILD/REF/SOURCES/WIDGETS_CHILD/PREFS_CHILD_ANCHOR）；新增 `find_group_children_end`（按 name/path 动态定位 PBXGroup + children 列表末尾）与 `find_app_sources_files_end`（app 目标 buildPhases → Sources phase files 列表末尾）；BuildFile/FileRef 改插 section End 标记前；未知/歧义 group 响亮报错不写盘；`uuids_for` 与幂等语义零改动 |

## 六、风险点与边界

1. **group 名歧义**：若未来出现两个 `name`/`path` 相同的 PBXGroup，脚本会 `SystemExit` 报歧义而非猜测——宁可失败不可错插（当前 pbxproj 无歧义，实测单命中）。
2. **app 目标匹配**：`/\* LyricsMTMR \*/` 正则要求注释精确等于 `LyricsMTMR`，不会误中 `LyricsMTMRTests`；若未来改目标名需同步脚本（当前工程无此风险）。
3. **行为差异说明**：旧脚本把新文件插在 QuickReplyBarItem 之后（中段），新脚本统一插在段/列表末尾——pbxproj 条目顺序对构建无影响，属有意简化；UUID 确定性不变，历史已注册条目不受影响。
4. **group 语义**：`Tools:AddFilesProbe.swift` 的 group=Tools 匹配 `path = Tools` 的 PBXGroup（MTMR/Widgets/Tools 目录），文件实际路径与分组严格对应；沿用惯例 `Widgets:Foo.swift` 依旧可用（匹配 `path = Widgets`）。
5. **未覆盖**：不含文件删除（对应 `fix_files.py`）、不含多工程支持；测试目标文件注册仍须手工或另行处理（本脚本定位的是 app 目标，语义与旧脚本一致）。

## 七、文档登记

- 本报告登记于 `LyricsMTMR/docs/file-structure.zh.md`（第 16 轮报告行 + mindmap 第 7~16 轮）
- `iteration-log.md` 追加「第 16 轮 / 子任务 A」记录
