# 核对报告_第47轮_README更新日志补登v0.47

- 任务：t_f459714a（第 47 轮 / 子任务 B，text-processing-agent，分支 r47/changelog，工作区 .worktrees/round47-B）
- 日期：2026-08-15
- 性质：纯文档轮（零 Swift 源码改动，未触发构建/测试/全量回归）

---

## 一、版本决策

### 1.1 Info.plist 核对

| 项 | 值 | 出处 |
|---|---|---|
| CFBundleShortVersionString | 0.46 | LyricsMTMR/MTMR/Info.plist:22 |
| CFBundleVersion | 471 | LyricsMTMR/MTMR/Info.plist:24 |

第 46 轮收口由 0.45/470 升入（plutil -replace 落地），随 main=2ac8c9d 落地（iteration-log 第 46 轮父收口记录 :1768）。

### 1.2 git tag 核对

实测仅 3 枚，第 46 轮无新 tag 未发版：

- v1.0.0
- v0.8
- pre-opt-20260812-0114

### 1.3 决策

- **新增「v0.47（当前开发版本）」条目**（任务既定口径）：v0.46 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.47；版本史说明段补记 v0.47=第 46 轮（v0.46=第 45 轮 后追加）。
- 日志最高条目与 Info.plist 0.46/471 对齐（0.47/472 待收口）。
- **建议**父任务收口时同步升 Info.plist 至 0.47（CFBundleShortVersionString 0.46→0.47、CFBundleVersion 471→472，第 24/28/30~46 轮先例）。本卡仅建议不擅改。

---

## 二、12 项现状核对表（grep 实证）

| # | 核对项 | 实证（文件:行号） | 结果 |
|---|---|---|---|
| 1 | 114 种 widget 口径 | ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README.md:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 7+4+4+7=22，Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28 在位 + Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题 | README:37/:103（issue #40，appThemeRules/app-themes 机制） | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50/:55/:57-66 在位 | ✅ |
| 7 | 剪贴板快捷查看 | README:429 TODO 区勾选项（本轮 v0.47 条目插入 10 行后由 :419 后移，与第 46 轮提交后状态一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory + Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~46 轮修正后一致，连续第十六轮零新漂移 | ✅ |
| 8 | 版本史说明段 | README:150/:152 考古结论在位，本轮补记 v0.47=第 46 轮 | ✅ |
| 9 | 第 46 轮能力均为内部变更 | 轮询链同步网络调用异步化评估与治理（后端服务维度：评估结论「不值得全量异步化」+ RssUnread direct 并行扇出试点 + NetworkRobustnessContractTests 4 用例 + 475 用例实证 0 失败 + 锚点巡检连续第二十五轮 0 ERROR + Info.plist 0.46/471），零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 46 轮代码地标 | MTMRTests/NetworkRobustnessContractTests.swift **13 个 test func 实测**（grep -c，9 既有 + 4 新增 :434/:458/:479/:499 并行契约）；Widgets/Life/RssUnread.swift:59-99 并行扇出实测（DispatchGroup :68 + NSLock :69 + DispatchQueue.global().async :74 + group.wait(30s) :89）；scripts/anchor-patrol.py + docs/anchor-patrol.md；Info.plist 0.46/471 | ✅ |
| 11 | 更新日志 v0.46 条目在位 | README.md v0.46 条目在位（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 + git tag 体系 | Info.plist=0.46/471，日志最高 v0.47 对齐，0.47/472 待收口；git tag 三枚无新增 | ✅ |

**第 47 轮 A 卡方向承接段**：v0.47 条目承接段注明本轮 A 卡方向——「UserDefaults 持久化层审计与治理」（数据与存储维度，接 R42/R43 技术债延续面：全仓 UserDefaults 使用 48 处/约 15 个文件，键风格/默认值语义/读写对称性/历史遗留键盘点分类 → 根因修复真实问题 → 契约测试（defaultsOverride 注入模式先例）→ 全量回归实证）；board 实测 t_63cca7ed running 未收口 → 如实注明「进行中」，细节以 A 卡收口记录为准。

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| 条目 | 对应轮次 | iteration-log 出处 |
|---|---|---|
| v0.47（当前开发版本）新增条目正文 | 第 46 轮变更（A 卡：轮询链同步网络调用异步化评估与治理） | 父收口段 :1768（A 卡方向与 475 实证、Info.plist 0.46/471 落地、锚点连续第二十五轮 0 ERROR）+ t_80428b5b :1778-1787（A 卡记录，含 20 处盘点/评估结论/并行扇出实现/4 用例红绿双跑/475 实证）+ t_aef37fd2 :1789-1794（B 卡记录，含版本决策与 0.46/471 建议）+ t_020ee0c9 :1771-1776（C 卡记录，含锚点基线 PASS 67/ERROR 0） |
| v0.47 条目承接段（第 47 轮 A 卡方向） | 第 47 轮 A 卡（UserDefaults 持久化层审计与治理） | board 实测 t_63cca7ed running 未收口 → 注明「进行中」，细节以 A 卡收口记录为准（先例：第 45/46 轮 B 卡对当轮 A 卡的同型处理） |
| v0.46 条目降历史段 | — | 第 46 轮 B 卡记录（:1789-1794）确认原条目内容 |
| 版本史 v0.47=第 46 轮 | — | 第 46 轮父收口（:1768）确认轮次编号 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：python3 scripts/anchor-patrol.py → **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 报告登记 155 行 = 第 46 轮收口后口径，与第 46 轮收口基线一致，连续第二十五轮 0 ERROR 保持）
- **改动后复跑**：同口径 **PASS 67 / WARN 16 / INFO 5 / ERROR 0 退出码 0**（REGISTRY 155 行——本卡核对报告登记前口径；报告登记后预期 +1 → 156）
- 结论：锚点双向一致，本轮 README/file-structure/iteration-log 改动零锚点回归；机器检查连续第二十六轮 0 ERROR

---

## 五、改动清单

1. **README.md**（3 处改动）：
   - ① 更新日志区置顶新增「v0.47（当前开发版本）」条目：承接段（第 46 轮变更摘要 + 第 47 轮 A 卡方向承接段注明「进行中」）+ 「工程与稳定性」3 项——轮询链同步网络调用异步化评估与治理（后端服务维度）/ 锚点巡检收口复跑接入保持（连续第二十五轮）/ 工程版本号对齐（0.45/470 → 0.46/471）
   - ② v0.46 条目标题移除「（当前开发版本）」标注
   - ③ 版本史说明段补记 v0.47=第 46 轮（v0.46=第 45 轮 后追加）
2. **iteration-log.md**：末尾补建「### 子任务记录」小节头（父分支预建头 b2cd95e 已提供「## 第 47 轮」+「### 父任务」预览行）+ 追加本卡记录（标注「第 47 轮 / 子任务 B」）
3. **LyricsMTMR/docs/file-structure.zh.md**：mindmap「第 7~46 轮」→「第 7~47 轮」+ 核对报告_第47轮 报告行登记（无重复行）
4. **核对报告_第47轮_README更新日志补登v0.47.md**：本报告（分支根目录，新建）

---

## 六、未虚构声明

- v0.47 条目正文全部来自第 46 轮 iteration-log 实证记录（父收口段 :1768 + A 卡 t_80428b5b :1778-1787 + B 卡 t_aef37fd2 :1789-1794 + C 卡 t_020ee0c9 :1771-1776 子任务记录）与 A 卡验证报告《验证报告_第46轮_轮询链异步化评估与治理.md》（同库实证），未虚构。
- 第 47 轮 A 卡方向承接段（UserDefaults 持久化层审计与治理）摘自 A 卡 board 任务 body 实测（t_63cca7ed），board 实测 running 未收口，如实注明「进行中」，未虚构收口细节。
- 12 项现状核对全部为本次实际 grep/ls/sed 实证，行号为本次实测值。

---

## 七、风险点

1. **README 行号位移**：v0.47 条目插入 10 行后，README 内引用行号整体后移（剪贴板 TODO 勾选项 :419 → :429）——历史条目引用为既有记录，不影响本轮交付；后续轮次核对以实测为准。
2. **第 47 轮 A 卡未收口**：承接段注明「进行中」，父任务收口时若 A 卡已收口可据实更新细节（先例：第 45/46 轮 B 卡对当轮 A 卡的同型处理）。
3. **REGISTRY 计数**：本卡核对报告登记后 anchor-patrol REGISTRY 预期 155 → 156（第 46 轮 B/C 报告登记先例）。
4. **iteration-log / file-structure 合并**：本卡补建的「### 子任务记录」头与父任务收口时的并行重组预期产生合并冲突（第 33/35/38/39/40/41/46 轮先例），file-structure 报告行归位同理，由父任务收口按 python 重组处置。
