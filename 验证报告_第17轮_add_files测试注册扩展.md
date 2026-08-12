# 验证报告_第17轮_add_files测试注册扩展

> 第 17 轮（功能/优化迭代第 5 轮）子任务 A · 工程规范 · code-agent · 分支 r17/tooling（基于 main@e231128）
> 日期：2026-08-12

## 一、结论摘要

`LyricsMTMR/Scripts/add_files.py` 扩展完成：新增 `Tests:` 前缀调用形态，测试文件可**一键注册**进单测目标（遗留问题 9 后半句闭环）。实证通过：探针测试文件 `AddFilesProbeTests.swift` 经 `add_files.py Tests:AddFilesProbeTests.swift` 注册 → pbxproj 4 处条目全部写入且落点正确（PBXBuildFile/PBXFileReference 段尾、group child 落 **MTMRTests 分组**、Sources 条目落 **LyricsMTMRTests 单测目标** Sources phase——app 目标零改动）→ xcodebuild test **TEST SUCCEEDED 131 用例 0 失败**（129 基线 + 2 探针全过）+ xcodebuild build **BUILD SUCCEEDED** → 二次运行幂等（skip）→ 未知组失败模式响亮报错且 pbxproj 零改动 → 探针与注册条目清理干净，仓库恢复基线（仅脚本改动）。

## 二、背景与设计

### 1. 遗留问题

第 16 轮 add_files.py 锚点修复后，Widgets 新文件可一键注册（遗留⑧闭环），但**新增测试文件仍需手工 4 处注册**（PBXBuildFile / PBXFileReference / group child / Sources phase，且需避 app 目标落入单测目标）——第 13~16 轮每轮都手工处理，是重复劳动与出错点（遗留 9 后半句）。典型手工注册（第 15/16 轮测试文件）：`CA8F2B*` 前缀 UUID + MTMRTests 分组 child + B082B25D phase 条目，每文件 4 处。

### 2. 调用形态

```
python3 Scripts/add_files.py Tests:FooTests.swift          # 测试文件（单测目标）
python3 Scripts/add_files.py Widgets:Foo.swift             # app 文件（保持原语义）
python3 Scripts/add_files.py Tools:Foo.swift Tests:FooTests.swift   # 混合一次注册
```

`Tests:` 前缀是保留字：触发测试模式（目标分组 MTMRTests、目标 target LyricsMTMRTests）。其余 `组名:文件名` 走原有 app 模式。

### 3. 注册链设计

| 条目 | app 模式（原） | 测试模式（新增） |
|:---|:---|:---|
| PBXBuildFile | `C0FF` + sha1(name)[:20]，插 `/* End PBXBuildFile section */` 前 | `C1FF` + sha1(name)[:20]，同段尾 |
| PBXFileReference | `C0FE` + sha1(name)[:20]，插 section End 标记前 | `C1FE` + sha1(name)[:20]，同段尾 |
| group child | 按 name/path 动态定位 PBXGroup，插 children 末尾 | **MTMRTests 分组**（path = MTMRTests），插末尾 |
| Sources phase | app 目标 LyricsMTMR buildPhases → Sources，插 files 末尾 | **单测目标 LyricsMTMRTests**（B082B260）buildPhases → Sources（B082B25D），插 files 末尾 |

关键决策：
- **UUID 命名空间隔离**：测试文件用独立前缀 `C1FE`（ref）/`C1FF`（build），app 文件保持 `C0FE`/`C0FF`——同名 app 文件与测试文件不会撞 UUID，两条注册链可区分，且确定性幂等语义不变（ref 已存在即 skip）。
- **目标解析通用化**：原 `find_app_sources_files_end` 硬编码 app 目标，重构为 `find_target_sources_files_end(text, target)`，按目标名精确匹配（正则 `/\* LyricsMTMRTests \*/` 不会误中 `LyricsMTMR`，反之亦然），从目标 buildPhases 解析其自己的 Sources phase。
- **两阶段写盘**：先对原始文本做**全部校验**（END 标记存在、各分组 children 列表、app/测试目标 Sources phase 全部定位成功），再按 offset 从文件尾向前批量插入、最后一次性写盘——任何一步失败都在写盘前 `SystemExit`，杜绝半注册（延续第 16 轮修复风格并更严格：校验与写入彻底分离）。
- **app 目标零改动保证**：测试模式只写 MTMRTests 分组 + B082B25D phase，app 的 B082B24B phase 与 Widgets 等分组完全不被触碰。

## 三、实证过程与结果

### 1. 探针注册（4 处条目落点验证）

新建 `MTMRTests/AddFilesProbeTests.swift`（2 个测试方法）后：

```
$ python3 Scripts/add_files.py Tests:AddFilesProbeTests.swift
add: Tests/AddFilesProbeTests.swift
done
```

pbxproj 实测 4 处条目（grep AddFilesProbeTests）：

| # | 条目 | 落点 | 验证 |
|:---|:---|:---|:---|
| 1 | PBXBuildFile `C1FF1149104610CC3A7F6467 /* AddFilesProbeTests.swift in Sources */` | :242，紧邻 `/* End PBXBuildFile section */` 之前 | ✅ 段尾 |
| 2 | PBXFileReference `C1FE1149104610CC3A7F6467 /* AddFilesProbeTests.swift */` | :510，紧邻 `/* End PBXFileReference section */` 之前 | ✅ 段尾 |
| 3 | group child `C1FE1149104610CC3A7F6467 /* AddFilesProbeTests.swift */,` | :652，**MTMRTests 分组**（B082B264，path = MTMRTests）children 列表末尾 | ✅ 测试分组 |
| 4 | Sources phase `C1FF1149104610CC3A7F6467 /* AddFilesProbeTests.swift in Sources */,` | :1313，**单测目标 B082B260** 的 Sources phase（B082B25D）files 列表末尾 | ✅ 单测 phase |

落点语义核对：app 目标 Sources phase（B082B24B）grep 零命中 → **绝不落 app 目标**成立；UUID 前缀 C1FE/C1FF 与 app 文件 C0FE/C0FF 命名空间隔离成立。

### 2. 构建 + 测试实证

```
$ xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/LyricsMTMR-dd-r17a-test
** TEST SUCCEEDED **   — 131 tests, 0 failures (0 unexpected)
   （129 基线 + 2 探针 AddFilesProbeTests 全过；探针被编译进 LyricsMTMRTests 目标并真实执行）

$ xcodebuild build -project LyricsMTMR.xcodeproj -scheme MTMR -configuration Debug \
    CODE_SIGNING_ALLOWED=NO -derivedDataPath /tmp/LyricsMTMR-dd-r17a-build
** BUILD SUCCEEDED **
```

独立 derivedDataPath，未污染仓库；本轮约束明确分支内 build+test 实证足够，未触发全量回归（父任务基线 129 用例）。

### 3. 幂等实证（二次运行 skip）

```
$ python3 Scripts/add_files.py Tests:AddFilesProbeTests.swift
skip (present): AddFilesProbeTests.swift
nothing to do
```

pbxproj 保持 4 行新增（git diff 前后一致），未重复写入 → 确定性 UUID 幂等成立。

### 4. 混合注册实证（app + 测试同一次调用）

```
$ python3 Scripts/add_files.py Tools:MixedProbe.swift Tests:MixedProbeTests.swift
add: Tools/MixedProbe.swift
add: Tests/MixedProbeTests.swift
done
```

| 文件 | BuildFile/FileRef | group child | Sources phase |
|:---|:---|:---|:---|
| MixedProbe.swift | C0FE/C0FF（app 前缀） | Tools 分组末尾 :789 | **app** B082B24B 末尾 :1299 |
| MixedProbeTests.swift | C1FE/C1FF（测试前缀） | MTMRTests 分组末尾 :657 | **单测** B082B25D 末尾 :1321 |

一次调用双链各归其位，互不干扰。

### 5. 失败模式实证（响亮而非静默，不写盘）

```
$ python3 Scripts/add_files.py NoSuchGroup:Probe2.swift
add: NoSuchGroup/Probe2.swift
group not found: NoSuchGroup     # SystemExit，exit=1
$ grep -c Probe2 project.pbxproj → 0
```

且混合失败场景（合法 Tests 条目 + 未知组条目同一调用）同样整体回滚：`skip (present)` 后 `group not found` exit=1，pbxproj 零改动——校验在写盘前完成，任何定位失败都中断全程。

### 6. 清理与恢复

```
$ rm MTMRTests/AddFilesProbeTests.swift
$ git checkout -- LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj
$ git status --short
 M LyricsMTMR/Scripts/add_files.py      # 仅脚本扩展，仓库干净
```

## 四、变更明细

| 文件 | 改动 |
|:---|:---|
| `LyricsMTMR/Scripts/add_files.py` | 唯一生产改动：新增 `Tests:` 前缀测试模式（目标分组 MTMRTests / 目标 target LyricsMTMRTests / UUID 前缀 C1FE+C1FF）；`find_app_sources_files_end` 重构为 `find_target_sources_files_end(text, target)` 支持按目标名解析 Sources phase；两阶段写盘（先全量校验后统一插入写盘）；app 模式行为与 C0FE/C0FF UUID 零改动 |

## 五、风险点与边界

1. **`Tests:` 保留字**：分组名恰好叫 Tests 的 app 文件无法用 `Tests:name` 注册（脚本无此需求——测试文件本就不进 app 分组；若未来出现同名 PBXGroup 需调整，当前无冲突）。
2. **目标匹配**：`/\* LyricsMTMRTests \*/` 正则精确匹配单测目标块，不会误中 app 目标（`LyricsMTMR` 后需紧跟空格 + `*/`）；app 目标匹配同理（第 16 轮已实证）。
3. **测试文件物理路径**：脚本只写 pbxproj 注册，文件需先放到 `LyricsMTMR/MTMRTests/` 目录（与 MTMRTests 分组 path 对应）；不校验文件存在性（与 app 模式一致，注册先行）。
4. **幂等判定**：按 ref UUID 是否已在文本中判断；C1FE/C1FF 与 C0FE/C0FF 命名空间隔离，同名文件跨模式注册互不误判。
5. **未覆盖**：不含文件删除（对应 `fix_files.py`）、不含多工程支持；测试文件若同时需进 app 目标（不应发生）需手工处理——脚本语义就是「测试文件只进单测目标」。
6. **两阶段校验**：所有定位基于原始文本一次性完成，插入按 offset 降序应用——offset 有效性不依赖前序插入，批量写盘原子性更强（相较第 16 轮逐段 replace 更严格）。

## 六、文档登记

- 本报告登记于 `LyricsMTMR/docs/file-structure.zh.md`（第 17 轮报告行 + mindmap 第 7~16 轮→第 7~17 轮）
- `iteration-log.md` 追加「第 17 轮 / 子任务 A」记录
