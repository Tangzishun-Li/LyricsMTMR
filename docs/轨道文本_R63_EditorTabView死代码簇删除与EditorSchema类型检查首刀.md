# 轨道文本_R63_EditorTabView死代码簇删除与EditorSchema类型检查首刀

> 2026-08-25，编排续链卡 t_36ba0ba9（r62-integ t_10669277 收口释放）建轨。
> 双主线：①用户拍板的 EditorTabView 死代码簇删除专项（决策 A）；②r62-d 调研 P1 首刀（EditorSchema 类型检查治理）。
> 铁律延续（轨道文本_R62 §7，常设）：**重型构建一律串行**，在飞重型构建卡 ≤2——本轮恰 2 张执行卡，不再加第三张构建卡。

## §1 取证链（2026-08-25 编排卡 grep 实证）

| # | 证据 | 结果 |
|---|------|------|
| E1 | 全仓 `--include='*.swift'` grep `'EditorTabView(\|ElementPaletteView(\|TouchBarPreviewView(\|PropertiesInspectorView('` | 仅定义处命中，构造调用零命中（继 r57-d 定性、r60-b 复核、t_32f6ffe1 run548 三验后的第四重验证） |
| E2 | LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj grep 四文件名 | 恰 16 行注册待摘（PBXBuildFile/PBXFileReference/group children） |
| E3 | LyricsMTMR/docs/file-structure.zh.md:81 | Editor/ 目录注释行含「EditorTabView」提及，随删须同步 |
| E4 | LyricsMTMR/MTMR/Preferences/Editor/EditorSchema.swift:173 | `private static let items: [String: ItemSchema] = build([...])` 单巨表达式在位——R54 定位类型检查 1308ms 单表达式（logs/第54轮/构建性能分析报告_第54轮_t_bd3381c7.md:59 起，Top10 占 32% :57），P1 未做成立 |
| E5 | LyricsMTMR/MTMRTests/SchemaDomainMigrationContractTests.swift:85,:92-93 | 运行时口径 278 条冻结锚点在位——两执行卡共同金标准 |
| E6 | 用户拍板 | t_32f6ffe1 comment（desktop，2026-08-25 16:29）：**方向 A 删除四文件 + pbxproj 摘除注册**，执行规格冻结于该卡 comment 213 |

## §2 环境事实

- 板 999，库 `/Users/litz/.hermes/kanban/boards/999/kanban.db`（注意不是默认库路径，直查 sqlite 用它）。
- 仓库 `/Users/litz/codespace/MTMR with LyricsX`（无尾空格）；worktree 在 `.worktrees/`；R63 起点 main=c5f214f（Info.plist 0.62/487）。
- 一切 xcodebuild 走 `sh scripts/build-with-lock.sh <原命令>`（r62-b 交付）；机器 8GB M1。
- GitHub 需代理 `export https_proxy=http://127.0.0.1 7890` 即 `export https_proxy=http://127.0.0.1:7890 http_proxy=http://127.0.0.1:7890`（2026-08-25 16:40 nc 探测 7890 已恢复监听）。

## §3 目录所有权表（每文件唯一属主，别人只读）

| 属主 | 文件 |
|------|------|
| r63-a | 删除 `LyricsMTMR/MTMR/Preferences/Editor/EditorTabView.swift`(470)/`ElementPaletteView.swift`(364)/`TouchBarPreviewView.swift`(400)/`PropertiesInspectorView.swift`(449)；`LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj`（摘 16 行注册）；`LyricsMTMR/docs/file-structure.zh.md`（仅 :81 注释行去 EditorTabView 提及，其余行不动） |
| r63-b | `LyricsMTMR/MTMR/Preferences/Editor/EditorSchema.swift`；（可选）新增 `LyricsMTMR/MTMRTests/` 下本卡专属测试文件 |
| INTEG | Info.plist / README / docs/轮次简报 / docs/轮次速查.md / iteration-log / file-structure 其余登记行 / 本文件 §7 追加 |

冲突规则：a∩b 文件交集为空；轨道文本只有编排卡与 INTEG 可改正文，子卡只许在卡 comment 记录。

## §4 契约

### 4.1 r63-a 死代码簇删除（用户决策 A 落地）

- git rm 四文件（净 -1683 行）；project.pbxproj 摘除且仅摘除四文件注册（恰 16 行）；file-structure.zh.md:81 注释同步。
- 验收：① 经锁脚本增量构建 SUCCEEDED；② SchemaDomainMigrationContractTests 全绿（EditorSchema 本卡未动，278 锚点原样）；③ 删后 E1 grep 仍零命中；④ 受影响套件 0 失败。

### 4.2 r63-b EditorSchema 类型检查治理 P1 首刀

- 目标：EditorSchema.swift:173 单巨表达式的编译期负担（R54 Top10 慢文件占类型检查 32%）。
- 手段：显式类型标注 / 表达式拆分 / 分段构造等**编译期**减负；运行时语义零变化。
- 红线：① SchemaDomainMigrationContractTests.swift:92-93 的 278 冻结锚点必须**原样**全绿（不许改锚点数字/文案适配）；② item 级元数据零变化；③ 不碰 pbxproj（文件已注册）；④ 同目录四文件正被 r63-a 删除，本卡不得引用或修改它们（run548 复核 EditorSchema 对其零引用，若动手时发现引用立即停手上报，不得自行扩大范围）。
- 验收：① 经锁脚本增量构建 SUCCEEDED；② SchemaDomainMigrationContractTests 全绿；③ 受影响套件 0 失败；④ 新增测试仅限 LyricsMTMR/MTMRTests/ 本卡专属新文件。

## §5 验收总则

1. 每执行卡：增量构建 SUCCEEDED（走锁脚本）+ 自有锚点全绿 + 受影响套件 0 失败。
2. INTEG 里程碑：整体构建 + **全量回归一次 0 失败（隔代规则 R63 到轮触发：R61 触发→R62 因用户点名里程碑规则外执行→R63 按规则触发）** + 版本顺延 0.62/487→0.63/488 + 简报三件套 + 速查表滚动（含「EditorTabView 死代码簇处置」候选行闭环改写为已删除、「MTMR_BUILD_JOBS 缺省复核」行保留）+ 报告归档 logs/第63轮/ + file-structure 登记 + 锚点巡检 0 ERROR + push main（fetch 复核 main=origin/main）。

## §6 迭代节奏红线（承 R62 §7，全板常设）

并行的是「开发」，串行的是「构建」。本轮执行卡少而精（2 张构建卡）；分析/文档/决策类卡不受限，但其内部同样禁止绕过锁脚本裸跑 xcodebuild。

## §7 追加式更新日志

- 2026-08-25 编排卡 t_36ba0ba9 建轨：§1 取证六条（E6=用户决策 A）、§3 所有权冻结、§4 双契约、§5 R63 到轮触发全量回归。
