# 核对报告_第38轮_README更新日志补登v0.38

- 轮次：第 38 轮（功能/优化迭代第 26 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r38/changelog）
- 基准：main@f875f68（第 37 轮收口提交，工作区预建同点，git 状态初始干净）
- 日期：2026-08-14

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.37（:22）/ CFBundleVersion=462（:24） | 第 37 轮收口由 0.36/461 升入随 main f875f68 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 37 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.38（当前开发版本）」条目（任务既定口径）——v0.37 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.38；版本史说明段补记 v0.38=第 37 轮。日志最高条目 v0.38 与 Info.plist 0.37/462 对齐（0.38/463 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.38（CFBundleShortVersionString 0.37→0.38、CFBundleVersion 462→463），第 24/28/30~37 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致；ItemsParsing.swift:492-591 ItemTypeRaw enum 98 case（python 花括号配平精确计数）+ :258 预定义 14 键注释 + :601 回退 98 分支 switch 注释 | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布 :348/:350/:352/:354 = 7+4+4+7=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ 历史条目 :275 + Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55-66（背景+工作机制+风险，含 macOS 26 封堵适配记录） | ✅ |
| 7 | 剪贴板快捷查看 | README:329 TODO 区勾选项；Core/BarItemFactory.swift:212 case .clipboardHistory + Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~37 轮修正后一致，连续第八轮零新漂移（README 行号 :329 为实测，第 37 轮记录引 :319 为改动前基线值，见风险点 1） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.38=第 37 轮，本轮补记） | ✅ |
| 9 | 第 37 轮能力均内部变更 | switch 兜底契约补齐 8 用例、契约测试 165→173、键集 93 键零改动、锚点巡检连续第九轮 0 ERROR、Info.plist 0.37/462——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 37 轮代码地标 | ItemsParsing.swift:634-1082 registeredTypeDecoders **93 键实测**（python 精确计数：首 cpu 末 base64Tool，audioSpectrum 不在注册表）+ switch 保留 5 类 :1108 staticButton/:1174 group/:1178 expandable/:1240 themeSwitch/:1258 audioSpectrum；MTMRTests/ItemTypeDecodeRegistryTests.swift **173 个 test func 实测**（grep -c）；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.37/462 | ✅ |
| 11 | 更新日志 v0.37 条目 | README v0.37 条目在位且与第 37 轮记录一致（本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.37/462，日志最高 v0.38（本轮补登后对齐），0.38/463 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 37 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.38（当前开发版本）新增 | 第 37 轮 | 父收口段 :1519（合并提交点 + Info.plist 0.37/462 + 421 用例实证 + 锚点复跑） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 37 轮 | t_a47cdcf3 :1531-1537（A 卡：4 类 8 用例明细、165→173、93 键零改动、421 用例实证、文档四处同步、锚点复跑连续第九轮） | 同上 |
| 同上（版本建议） | 第 38 轮 | t_8b91e906 :1539-1544（B 卡：版本决策建议 0.38/463 待收口） | 本次补登执行依据 |
| v0.37 降历史段 | 第 37 轮 | 第 37 轮收口落地（Info.plist 0.37/462 随 main f875f68） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.38=第 37 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 37 轮收口后基线逐项一致；WARN 11 项均为 known 已登记记录性位移，INFO 5 项含预期消失/记录性证据；REGISTRY 报告登记 120 行去重后 120 个文件）。第 29 轮落地后 0 ERROR 保持（第 37 轮收口后连续第十轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md 改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.38（当前开发版本）」条目（工程与稳定性 3 项）；② v0.37 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.38=第 37 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（先建「## 第 38 轮（功能/优化迭代第 26 轮）」+「### 子任务记录」小节头——第 33/35 轮教训；父任务未预建故本卡补建；标注「第 38 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~37 轮」→「第 7~38 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第38轮_README更新日志补登v0.38.md | 本报告 | 交付物 |

README v0.38 条目内容（3 项）：
1. **保留 5 类非注册分支 switch 路径契约测试补齐（穷尽性兜底运行时断言化）**：staticButton/group/expandable/themeSwitch 4 类 8 用例（audioSpectrum 已有回退锚点不重复），契约测试 165→173、键集 93 键零改动、零生产代码改动、穷尽性兜底从编译期保证升级为运行时行为断言、421 用例实证（413 基线+新增 8）0 失败、任务预算零偏差；
2. **锚点巡检收口复跑接入保持**：连续第九轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.36/461 → 0.37/462。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.38 条目内容全部摘自 iteration-log 第 37 轮实证记录（父收口段 :1519、t_a47cdcf3 :1531-1537、t_8b91e906 :1539-1544），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **第 37 轮记录 README 行号引用与实测现位存在记录性差异**：第 37 轮 B 卡记录引 holidayCountdown 历史条目 :254、剪贴板 TODO :319，实测现位 :275 / :329（差 +10~21）。取证：git log -- README.md 实证 README 自第 37 轮 B 卡提交 65d0e8a 后零改动（当前即 65d0e8a 状态）；git show 65d0e8a 实测剪贴板行 :329、holidayCountdown :275；git show be0f50a（第 36 轮 B 卡提交）实测剪贴板行 :319 —— 判定第 37 轮记录引用的是其改动前基线值（或沿用旧记录），非真实漂移；该两行不在 anchor-patrol 锚点集内，机器检查不覆盖。本轮报告以实测为准，建议后续轮次引用 README 行号时以「改动后复测」为准（同第 31~37 轮对 Swift 行号的惯例）。
2. **0.38/463 待收口**：日志最高条目 v0.38 与 Info.plist 0.37/462 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（995 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 patch 工具定点修改完成；patch 工具正常工作，无影响。
