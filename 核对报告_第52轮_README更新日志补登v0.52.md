# 核对报告_第52轮_README更新日志补登v0.52

- 任务：t_932a19af（第 52 轮 / 子任务 B，text-processing-agent，分支 r52/changelog，工作区 .worktrees/round52-B）
- 日期：2026-08-17
- 性质：纯文档轮（零 Swift 源码改动，未触发构建/测试/全量回归；第 52 轮分解前全量回归 533 由父任务实证口径，本卡纯文档不重复跑）

---

## 一、版本决策

### 1.1 Info.plist 核对

| 项 | 值 | 出处 |
|---|---|---|
| CFBundleShortVersionString | 0.51 | LyricsMTMR/MTMR/Info.plist（plutil/PlistBuddy 实测） |
| CFBundleVersion | 476 | LyricsMTMR/MTMR/Info.plist（plutil/PlistBuddy 实测） |

第 51 轮收口由 0.50/475 升入（plutil -replace 落地），随 main=e1527c5 落地（iteration-log 第 51 轮父收口记录：「Info.plist 0.51/476 收口落地（plutil -replace，B 卡建议执行）」）。

### 1.2 git tag 核对

实测仅 3 枚，第 51 轮无新 tag 未发版（git tag -l 实测）：

- v1.0.0
- v0.8
- pre-opt-20260812-0114

### 1.3 决策

- **新增「v0.52（当前开发版本）」条目**（任务既定口径）：v0.51 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.52；版本史说明段补记 v0.52=第 51 轮（v0.51=第 50 轮 后追加）。
- 日志最高条目与 Info.plist 0.51/476 对齐（0.52/477 待收口）。
- **建议**父任务收口时同步升 Info.plist 至 0.52（CFBundleShortVersionString 0.51→0.52、CFBundleVersion 476→477，第 24/28/30~51 轮先例）。本卡仅建议不擅改。

---

## 二、12 项现状核对表（grep 实证）

| # | 核对项 | 实证（文件:行号） | 结果 |
|---|---|---|---|
| 1 | 114 种 widget 口径 | ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README.md:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 7+4+4+7=22（:348/:350/:352/:354），Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28 在位 + Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题 | README:37/:101-103（issue #40，appThemeRules/app-themes 机制在位） | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成行）/ :53（机制标题）/ :55（背景）/ :57（工作机制）/ :59-62（机制 4 条）/ :64（已知风险）/ :66-67（风险 2 条）在位 | ✅ |
| 7 | 剪贴板快捷查看 | README:482 TODO 区勾选项（本轮 v0.52 条目插入 13 行后由 :469 后移，与第 51 轮提交后状态一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory + Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~51 轮修正后一致，连续第二十一轮零新漂移 | ✅ |
| 8 | 版本史说明段 | README:150/:152 考古结论在位，本轮补记 v0.52=第 51 轮 | ✅ |
| 9 | 第 51 轮能力为「用户可见新功能」 | 桌面歌词窗口 MVP（前端体验/UI 维度——歌词产品空白面补全：NSPanel 非激活悬浮窗 + 三行竖排卡拉 OK 逐字高亮 + 占位三态 + 位置记忆 + 设置歌词 Tab 桌面歌词区 + 纯逻辑抽 3 组（LyricsKaraokeMapper/DesktopLyricsLayout/DesktopLyricsVisibility）+ 新增键全带前缀 + DesktopLyricsWindowTests 20 用例红→绿双跑 + 受影响套件+金丝雀 81 用例 0 失败 + 锚点连续第三十一轮 0 ERROR + Info.plist 0.51/476），属用户可见新功能 → 以「#### 新增」条目入 v0.52 条目（与第 19 轮既定原则「内部变更不入功能列表」对应的相反侧——用户可见功能入功能列表） | ✅ |
| 10 | 第 51 轮代码地标 | MTMR/Core/DesktopLyricsWindowController.swift 599 行存在（本轮 A 卡 marquee 改造对象，:247 byTruncatingTail/:253 byClipping 截断现状）；MTMRTests/DesktopLyricsWindowTests.swift 20 个 test func 实测（grep -c 20）；LyricsEngine.swift 引用 LyricsKaraokeMapper；AppSettings.swift:178/:182/:186 三键全带 com.lyricsmtmr.desktopLyrics. 前缀；Info.plist 0.51/476 | ✅ |
| 11 | 更新日志 v0.51 条目在位 | README.md:167 条目标题（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 + git tag 体系 | Info.plist=0.51/476，日志最高 v0.52 对齐，0.52/477 待收口；git tag 三枚无新增 | ✅ |

**第 52 轮 A 卡方向承接段**：v0.52 条目承接段注明本轮 A 卡方向——「桌面歌词窗口长行 marquee」（前端体验/UI 维度续面——R51 遗留候选闭环，接 R51 收口基线 533=513+20 + DesktopLyricsWindowTests 20）；board 实测 t_244c9649 running 未收口 → 如实注明「进行中」，细节以 A 卡收口记录为准（先例：第 45/46/47/48/49/50/51 轮 B 卡对当轮 A 卡的同型处理）。

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| 条目 | 对应轮次 | iteration-log 出处 |
|---|---|---|
| v0.52（当前开发版本）新增条目正文（#### 新增：桌面歌词窗口 MVP） | 第 51 轮变更（A 卡：桌面歌词窗口 MVP 落地） | 父收口记录（第 51 轮：合并提交点 C→A→B、整体实证 81 用例 0 失败（A 卡已跑受影响套件+金丝雀）、Info.plist 0.51/476 落地、锚点连续第三十一轮 0 ERROR）+ t_15a0c3b0（A 卡记录：NSPanel 悬浮窗/三行竖排/占位三态/位置记忆/纯逻辑抽 3 组/新增键前缀/20 用例红绿双跑/81 用例 0 失败）+ t_3faa5273（B 卡记录）+ t_7ea2a6dc（C 卡记录）+ A 卡验证报告《验证报告_第51轮_桌面歌词窗口MVP.md》（同库实证） |
| v0.52 条目「#### 工程与稳定性」2 项（锚点巡检/工程版本号对齐） | 第 51 轮收口口径 | 父收口记录（锚点巡检连续第三十一轮 0 ERROR，REGISTRY 176 行=第 50 轮 172 行+本轮 4 份报告；Info.plist 0.51/476 落地） |
| v0.52 条目承接段（第 52 轮 A 卡方向） | 第 52 轮 A 卡（桌面歌词窗口长行 marquee） | board 实测 t_244c9649 running 未收口 → 注明「进行中」，细节以 A 卡收口记录为准（先例：第 45~51 轮 B 卡对当轮 A 卡的同型处理） |
| v0.51 条目降历史段 | — | 第 51 轮 B 卡记录确认原条目内容 |
| 版本史 v0.52=第 51 轮 | — | 第 51 轮父收口记录确认轮次编号 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：python3 scripts/anchor-patrol.py → **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 报告登记 176 行 = 第 51 轮收口后实测口径（第 51 轮 4 份报告并入 logs/第51轮/，R51 收口归档提交），与第 51 轮收口基线一致，连续第三十一轮 0 ERROR 保持）
- **改动后复跑**：同口径 **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 177 行——本卡核对报告行已随 file-structure.zh.md 登记，176 → 177 预期 +1 达成）
- 结论：锚点双向一致，本轮 README/file-structure/iteration-log 改动零锚点回归；机器检查连续第三十一轮 0 ERROR

---

## 五、改动清单

1. **README.md**（共 3 处改动）：
   - ① 更新日志区置顶新增「v0.52（当前开发版本）」条目（:154，插入 13 行）：承接段（第 51 轮变更摘要——桌面歌词窗口 MVP 落地描述 + 第 52 轮 A 卡方向注明「进行中」）+ 「#### 新增」1 项（桌面歌词窗口 MVP）+ 「#### 工程与稳定性」2 项（锚点巡检收口复跑接入保持连续第三十一轮 / 工程版本号对齐 0.50/475 → 0.51/476）
   - ② v0.51 条目标题（:167）移除「（当前开发版本）」标注
   - ③ 版本史说明段（:152）补记 v0.52=第 51 轮（v0.51=第 50 轮 后追加）
2. **iteration-log.md**：末尾补建「### 子任务记录」小节头（父分支预建头 de7d9ff 已提供「## 第 52 轮」+「### 父任务」预览行）+ 追加本卡记录（标注「第 52 轮 / 子任务 B」，收口时父任务重组）
3. **LyricsMTMR/docs/file-structure.zh.md**：mindmap「第 7~51 轮」→「第 7~52 轮」+ 核对报告_第52轮 报告行登记（grep 计数 1 行，无重复行）
4. **核对报告_第52轮_README更新日志补登v0.52.md**：本报告（分支根目录，新建）

---

## 六、未虚构声明

- v0.52 条目正文全部来自第 51 轮 iteration-log 实证记录（父收口记录 + A 卡 t_15a0c3b0 + B 卡 t_3faa5273 + C 卡 t_7ea2a6dc 子任务记录）与 A 卡验证报告《验证报告_第51轮_桌面歌词窗口MVP.md》（同库实证），未虚构。
- 第 52 轮 A 卡方向承接段（桌面歌词窗口长行 marquee，前端体验/UI 维度续面——R51 遗留候选闭环，接 R51 收口基线 533）摘自 A 卡 board 任务标题/正文实测（t_244c9649），board 实测 running 未收口，如实注明「进行中」，未虚构收口细节。
- 12 项现状核对全部为本次实际 grep/ls 实测，行号为本次实测值。
- DesktopLyricsWindowController.swift（599 行）、DesktopLyricsWindowTests.swift 20 个 test func、AppSettings 3 键前缀、Info.plist 0.51/476 等代码地标均为本次实测，未虚构。

---

## 七、风险点

1. **README 行号位移**：v0.52 条目插入 13 行后，README 内引用行号整体后移（剪贴板 TODO 勾选项 :469 → :482）——历史条目引用为既有记录，不影响本轮交付；后续轮次核对以实测为准。
2. **第 52 轮 A 卡未收口**：承接段注明「进行中」，父任务收口时若 A 卡已收口可据实更新细节（先例：第 45~51 轮 B 卡对当轮 A 卡的同型处理）。
3. **REGISTRY 计数**：本卡核对报告登记后 anchor-patrol REGISTRY 预期 176 → 177（第 51 轮 B/C 报告登记先例）。
4. **iteration-log / file-structure 合并**：本卡补建的「### 子任务记录」头与父任务收口时的并行重组预期产生合并冲突（第 33/35/38/39/40/41/46/47/48/49/50/51 轮先例），file-structure 报告行归位同理，由父任务收口按 python 重组处置。