# 核对报告_第51轮_README更新日志补登v0.51

- 任务：t_3faa5273（第 51 轮 / 子任务 B，text-processing-agent，分支 r51/changelog，工作区 .worktrees/round51-B）
- 日期：2026-08-15
- 性质：纯文档轮（零 Swift 源码改动，未触发构建/测试/全量回归）

---

## 一、版本决策

### 1.1 Info.plist 核对

| 项 | 值 | 出处 |
|---|---|---|
| CFBundleShortVersionString | 0.50 | LyricsMTMR/MTMR/Info.plist:22 |
| CFBundleVersion | 475 | LyricsMTMR/MTMR/Info.plist:24 |

第 50 轮收口由 0.49/474 升入（plutil -replace 落地），随 main=68cf208 落地（iteration-log 第 50 轮父收口记录）。

### 1.2 git tag 核对

实测仅 3 枚，第 50 轮无新 tag 未发版：

- v1.0.0
- v0.8
- pre-opt-20260812-0114

### 1.3 决策

- **新增「v0.51（当前开发版本）」条目**（任务既定口径）：v0.50 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.51；版本史说明段补记 v0.51=第 50 轮（v0.50=第 49 轮 后追加）。
- 日志最高条目与 Info.plist 0.50/475 对齐（0.51/476 待收口）。
- **建议**父任务收口时同步升 Info.plist 至 0.51（CFBundleShortVersionString 0.50→0.51、CFBundleVersion 475→476，第 24/28/30~50 轮先例）。本卡仅建议不擅改。

---

## 二、12 项现状核对表（grep 实证）

| # | 核对项 | 实证（文件:行号） | 结果 |
|---|---|---|---|
| 1 | 114 种 widget 口径 | ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README.md:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 7+4+4+7=22（:348/:350/:352/:354），Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28 在位 + Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题 | README:37/:101-103（issue #40，appThemeRules/app-themes 机制在位） | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50/:55/:57-66 在位 | ✅ |
| 7 | 剪贴板快捷查看 | README:469 TODO 区勾选项（本轮 v0.51 条目插入 10 行后由 :459 后移，与第 50 轮提交后状态一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory + Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~50 轮修正后一致，连续第二十轮零新漂移 | ✅ |
| 8 | 版本史说明段 | README:150/:152 考古结论在位，本轮补记 v0.51=第 50 轮 | ✅ |
| 9 | 第 50 轮能力均为内部/合规变更 | 隐私清单补建与敏感数据面审计治理（安全与合规维度：PrivacyInfo.xcprivacy 补建 + pbxproj 四条目注册 + 必申 3 项（CA92.1/C617.1/3B52.1）+ 收集面诚实声明 2 项 + PrivacyManifestContractTests 13 用例红→绿双跑 + 513 用例实证 0 失败 + 锚点巡检连续第二十九轮 0 ERROR + Info.plist 0.50/475），零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则）；PrivacyInfo.xcprivacy 属合规面，作「工程与稳定性」条目入 v0.51 条目 | ✅ |
| 10 | 第 50 轮代码地标 | MTMRTests/PrivacyManifestContractTests.swift **13 个 test func 实测**（grep -c 13）；LyricsMTMR/MTMR/PrivacyInfo.xcprivacy 存在性（1806B）；LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj PrivacyInfo.xcprivacy 4 处注册命中；Info.plist 0.50/475 | ✅ |
| 11 | 更新日志 v0.50 条目在位 | README.md:164 v0.50 条目在位（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 + git tag 体系 | Info.plist=0.50/475，日志最高 v0.51 对齐，0.51/476 待收口；git tag 三枚无新增 | ✅ |

**第 51 轮 A 卡方向承接段**：v0.51 条目承接段注明本轮 A 卡方向——「桌面歌词窗口 MVP」（前端体验/UI 维度——歌词产品空白面补全，接 R50 收口基线 513）；board 实测 t_15a0c3b0 running 未收口 → 如实注明「进行中」，细节以 A 卡收口记录为准。

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| 条目 | 对应轮次 | iteration-log 出处 |
|---|---|---|
| v0.51（当前开发版本）新增条目正文 | 第 50 轮变更（A 卡：隐私清单补建与敏感数据面审计治理） | 父收口记录（第 50 轮：合并提交点 C→A→B、整体实证 513 用例 0 失败（A 卡 101.0s）、Info.plist 0.50/475 落地、锚点连续第二十九轮 0 ERROR）+ t_3821da31（A 卡记录：6 类盘点/必申 3 项/收集面 2 项/PrivacyInfo.xcprivacy 落地/pbxproj 注册/契约 13 用例红绿双跑/513 实证）+ t_def4fc28（B 卡记录：版本决策与 0.50/475 建议）+ t_d7b0c801（C 卡记录：锚点基线 PASS 67/ERROR 0 与 round-49 清理） |
| v0.51 条目承接段（第 51 轮 A 卡方向） | 第 51 轮 A 卡（桌面歌词窗口 MVP） | board 实测 t_15a0c3b0 running 未收口 → 注明「进行中」，细节以 A 卡收口记录为准（先例：第 45/46/47/48/49/50 轮 B 卡对当轮 A 卡的同型处理） |
| v0.50 条目降历史段 | — | 第 50 轮 B 卡记录确认原条目内容 |
| 版本史 v0.51=第 50 轮 | — | 第 50 轮父收口记录确认轮次编号 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：python3 scripts/anchor-patrol.py → **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 报告登记 172 行 = 第 50 轮收口后实测口径（R50 三子卡 4 份报告并入 + 报告归档 logs/ 按轮次分类后全量，R50 归档提交 adb2559），与第 50 轮收口基线一致，连续第三十轮 0 ERROR 保持）
- **改动后复跑**：同口径 **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 173 行——本卡核对报告行已随 file-structure.zh.md 登记，172 → 173 预期 +1 达成）
- 结论：锚点双向一致，本轮 README/file-structure/iteration-log 改动零锚点回归；机器检查连续第三十轮 0 ERROR

---

## 五、改动清单

1. **README.md**（3 处改动）：
   - ① 更新日志区置顶新增「v0.51（当前开发版本）」条目（:154，插入 10 行）：承接段（第 50 轮变更摘要 + 第 51 轮 A 卡方向承接段注明「进行中」）+ 「工程与稳定性」3 项——隐私清单补建与敏感数据面审计治理（安全与合规维度）/ 锚点巡检收口复跑接入保持（连续第二十九轮）/ 工程版本号对齐（0.49/474 → 0.50/475）
   - ② v0.50 条目标题（:164）移除「（当前开发版本）」标注
   - ③ 版本史说明段（:152）补记 v0.51=第 50 轮（v0.50=第 49 轮 后追加）
2. **iteration-log.md**：末尾补建「### 子任务记录」小节头（父分支预建头 1f621af 已提供「## 第 51 轮」+「### 父任务」预览行）+ 追加本卡记录（标注「第 51 轮 / 子任务 B」，收口时父任务重组）
3. **LyricsMTMR/docs/file-structure.zh.md**：mindmap「第 7~50 轮」→「第 7~51 轮」+ 核对报告_第51轮 报告行登记（grep 计数 1 行，无重复行）
4. **核对报告_第51轮_README更新日志补登v0.51.md**：本报告（分支根目录，新建）

---

## 六、未虚构声明

- v0.51 条目正文全部来自第 50 轮 iteration-log 实证记录（父收口记录 + A 卡 t_3821da31 + B 卡 t_def4fc28 + C 卡 t_d7b0c801 子任务记录）与 A 卡验证报告《验证报告_第50轮_隐私清单补建与敏感数据面审计治理.md》（同库实证），未虚构。
- 第 51 轮 A 卡方向承接段（桌面歌词窗口 MVP，前端体验/UI 维度——歌词产品空白面补全，接 R50 收口基线 513）摘自 A 卡 board 任务标题实测（t_15a0c3b0），board 实测 running 未收口，如实注明「进行中」，未虚构收口细节。
- 12 项现状核对全部为本次实际 grep/ls 实证，行号为本次实测值。
- PrivacyManifestContractTests 13 用例、PrivacyInfo.xcprivacy 存在性（1806B）、pbxproj 4 处注册等代码地标均为本次 grep/ls 实测，未虚构。

---

## 七、风险点

1. **README 行号位移**：v0.51 条目插入 10 行后，README 内引用行号整体后移（剪贴板 TODO 勾选项 :459 → :469）——历史条目引用为既有记录，不影响本轮交付；后续轮次核对以实测为准。
2. **第 51 轮 A 卡未收口**：承接段注明「进行中」，父任务收口时若 A 卡已收口可据实更新细节（先例：第 45/46/47/48/49/50 轮 B 卡对当轮 A 卡的同型处理）。
3. **REGISTRY 计数**：本卡核对报告登记后 anchor-patrol REGISTRY 预期 172 → 173（第 50 轮 B/C 报告登记先例）。
4. **iteration-log / file-structure 合并**：本卡补建的「### 子任务记录」头与父任务收口时的并行重组预期产生合并冲突（第 33/35/38/39/40/41/46/47/48/49/50 轮先例），file-structure 报告行归位同理，由父任务收口按 python 重组处置。
