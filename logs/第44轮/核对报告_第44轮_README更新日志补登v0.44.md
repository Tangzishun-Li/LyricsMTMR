# 核对报告_第44轮_README更新日志补登v0.44

- 轮次：第 44 轮（功能/优化迭代第 32 轮）/ 子任务 B（文档）
- 执行者：text-processing-agent（分支 r44/changelog）
- 基准：main@a5a12b0（第 43 轮收口提交）+ 父分支预建头 3179dd3（iteration-log 第 44 轮章节预建，工作区初始干净；分解前全量回归已由父任务实证——462 用例 0 失败，基线口径 462，隔代规则触发轮）
- 日期：2026-08-15

---

## 一、版本决策

| 项 | 实证 | 结论 |
|----|------|------|
| Info.plist | `LyricsMTMR/MTMR/Info.plist:21-24`：CFBundleShortVersionString=0.43（:22）/ CFBundleVersion=468（:24） | 第 43 轮收口由 0.42/467 升入随 main a5a12b0 落地 ✅ |
| git tag | `git tag -l` 实测仅 3 枚：v1.0.0 / v0.8 / pre-opt-20260812-0114 | 第 43 轮无新 tag 未发版 ✅ |

**决策**：新增「v0.44（当前开发版本）」条目（任务既定口径）——v0.43 条目降为历史段并移除「（当前开发版本）」标注，语义移交 v0.44；版本史说明段补记 v0.44=第 43 轮。日志最高条目 v0.44 与 Info.plist 0.43/468 对齐（0.44/469 待收口）。

**建议（仅建议不擅改）**：父任务收口时同步升 Info.plist 至 0.44（CFBundleShortVersionString 0.43→0.44、CFBundleVersion 468→469），第 24/28/30~43 轮先例。

---

## 二、12 项现状核对表（grep 实证 文件:行号）

| # | 核对项 | 实证（实测） | 结果 |
|---|--------|--------------|------|
| 1 | 114 种 widget 口径 | LyricsMTMR/docs/ITEMS_REFERENCE.md:3（全部 114 种）/ :59（114=98+14+2 含 holidayCountdown）；README:11/:25/:98 三处一致 | ✅ |
| 2 | 15 套主题 | examples/presets/ theme1~15.json 实存 15 个（ls 计数） | ✅ |
| 3 | 22 个设置 Tab | LyricsMTMR/MTMR/Preferences/UnifiedSettingsWindowController.swift:346 SettingsTab enum，case 分布（general/lyrics/slots/editor/keyBindings/services/about=7 + stock/pomodoro/weather/rss=4 + package/calendar/homekit/ai=4 + expense/dock/notification/systemMonitor/wellness/lifestyle/tools=7）=22；Tab 名与 README:41 逐字吻合 | ✅ |
| 4 | holidayCountdown | README:28（效率工具列表在位）+ Widgets/Life/HolidayCountdown.swift 在位 | ✅ |
| 5 | 应用专属主题（issue #40） | README:37/:101/:103/:109，appThemeRules / app-themes 机制在位 | ✅ |
| 6 | MediaRemote 机制与风险段 | README:50（集成能力列表）/ :55（背景+工作机制+风险段首行，含 macOS 15.4 entitlements 校验说明） | ✅ |
| 7 | 剪贴板快捷查看 | README:399 TODO 区勾选项（本轮 v0.44 条目插入 10 行后由 :389 后移，与第 43 轮提交后状态 :389 一致）；Core/BarItemFactory.swift:212 case let .clipboardHistory（创建 ClipboardHistoryItem）+ Core/ItemsParsing.swift:358 case clipboardHistory——两 Swift 行号与第 31~43 轮修正后一致，连续第十四轮零新漂移（README 位移已在风险点 1 说明） | ✅ |
| 8 | 版本史说明段 | README:150（### 版本史说明）/ :152（考古结论在位，映射已含 v0.43=第 42 轮，本轮补记 v0.44=第 43 轮） | ✅ |
| 9 | 第 43 轮能力均内部变更 | SecretsManager 密钥存储审计与治理（安全与合规维度——全仓 20 个 APIService 生命周期盘点分类（存储介质/传输方式/泄漏面/ATS 例外域 6 个逐项）；Keychain 切换机制完整实施（读穿回退+存量迁移+回退迁移+SecItem 状态检查+测试钩子）但默认保持 false 不翻转（Debug 77R6HZNK93 vs Release D6D8BR2QNB 双 DEVELOPMENT_TEAM 跨配置 ACL 风险论证）；真实问题 7 处修复（clear 双后端全清/迁移删明文副本/回退反向迁移/单一权威/写失败降级/硬编码检测 12 形态键+值掩码/AppSettings 10 处死代码旁路删除）；SecretsManagerContractTests 13 用例（红 14 failures→绿 13/13 双跑实证未放宽断言）；462 用例实证 0 失败（95.8s）；锚点巡检连续第二十一轮 0 ERROR；Info.plist 0.43/468）——零新 widget 零新用户功能 → 均不入功能列表（第 19 轮既定原则） | ✅ |
| 10 | 第 43 轮代码地标 | MTMRTests/SecretsManagerContractTests.swift **13 个 test func 实测**（grep -c）；Support/SecretsManager.swift useKeychain=false（:176）+ defaultsOverride（:184）/ keychainOverride（:187）测试钩子 + detectHardcodedKeys（:786 起，12 种形态键+值掩码 \*\*\*）；App/AppSettings.swift 死代码已删（仅余有引用的 deepseekModel/rssProvider）；scripts/anchor-patrol.py + docs/anchor-patrol.md 在位；Info.plist 0.43/468 | ✅ |
| 11 | 更新日志 v0.43 条目 | README v0.43 条目在位（:164，本轮仅移除「（当前开发版本）」标注，正文未动） | ✅ |
| 12 | 版本号一致性 / git tag | Info.plist=0.43/468，日志最高 v0.44（本轮补登后对齐），0.44/469 待收口；git tag 三枚无新增 | ✅ |

**新增发现 0 项。**

---

## 三、条目 → 轮次 → iteration-log 出处对照表

| README 条目 | 对应轮次 | iteration-log 出处（第 43 轮段） | 内容来源 |
|-------------|----------|----------------------------------|----------|
| v0.44（当前开发版本）新增 | 第 43 轮 | 父收口段 :1679（C→A→B 三条主线并入 + Info.plist 0.42/467 → 0.43/468 + 整体实证 462 用例 0 失败 + 锚点巡检收口复跑连续第二十一轮 0 ERROR + 下轮方向基线 462） | 概括 3 项变更（见改动清单 ①），全部摘录自实证记录，未虚构 |
| 同上（明细） | 第 43 轮 | t_d205d08d :1689-1697（A 卡：全仓 20 个 APIService 生命周期盘点分类（存储介质/传输方式/泄漏面/ATS 例外域 6 个逐项）、Keychain 切换机制完整实施但默认保持 false 不翻转（双 DEVELOPMENT_TEAM 跨配置 ACL 风险论证）、真实问题 7 处修复（clear 双后端全清/迁移删明文副本/回退反向迁移/单一权威/写失败降级/硬编码检测 12 形态键+值掩码/AppSettings 10 处死代码旁路删除）、SecretsManagerContractTests 13 用例（红 14 failures→绿 13/13 双跑实证未放宽断言）、462 用例实证（95.8s）0 失败、锚点复跑连续第二十轮） | 同上 |
| 同上（锚点轮次） | 第 43 轮 | t_16024e56 :1698-1703（第 43 轮 B 卡：README v0.43 补登 + 版本建议 0.43/468 + 锚点复跑连续第十九轮口径）+ t_0a46b5f7 :1683-1688（C 卡：收口复跑连续第二十轮口径） | 锚点「连续第二十一轮」取父收口段复跑口径（:1679） |
| v0.43 降历史段 | 第 43 轮 | 第 43 轮收口落地（Info.plist 0.43/468 随 main a5a12b0） | 本轮仅移除标注，正文未动 |
| 版本史说明段补记 | — | README:152 考古结论段（第 25 轮实证） | 映射追加「v0.44=第 43 轮」 |

---

## 四、锚点核对（anchor-patrol 机器断言实证）

- **改动前基线**：`python3 scripts/anchor-patrol.py` → **PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**（与第 43 轮收口后基线逐项一致；REGISTRY 报告登记 144 行去重后 144 个文件——第 43 轮 A/B/C 卡 4 份报告登记后口径，与第 43 轮收口记录一致）。第 29 轮落地后 0 ERROR 保持（第 43 轮收口后连续第二十一轮口径延续）。
- **改动后复跑 ×2**：README.md / file-structure.zh.md / iteration-log.md / 本核对报告改动完成后复跑两次，**均 PASS 72 / WARN 11 / INFO 5 / ERROR 0 退出码 0**，同口径零新漂移（REGISTRY 报告登记 145 行——较基线 144 增 1，为本卡核对报告登记所致，与第 43 轮先例同构）。
- 结论：本轮文档改动未引入任何锚点漂移，机器检查零回归（第 29 轮落地后连续第二十二轮 0 ERROR 保持）。

---

## 五、改动清单

| 文件 | 改动 | 性质 |
|------|------|------|
| README.md | ① 更新日志区置顶新增「v0.44（当前开发版本）」条目（工程与稳定性 3 项）；② v0.43 条目标题移除「（当前开发版本）」标注；③ 版本史说明段补记 v0.44=第 43 轮 | 唯一生产文件改动 |
| iteration-log.md | 末尾追加本卡记录（父分支预建「## 第 44 轮（功能/优化迭代第 32 轮）」+「### 父任务」头在父分支 3179dd3——本卡 worktree 恰基于该提交故预建头可见，仅补「### 子任务记录」小节头后追加；标注「第 44 轮 / 子任务 B」） | 轨迹记录 |
| file-structure.zh.md | mindmap「第 7~43 轮」→「第 7~44 轮」+ 核对报告行登记（无重复行，grep 校验） | 轨迹记录 |
| 核对报告_第44轮_README更新日志补登v0.44.md | 本报告 | 交付物 |

README v0.44 条目内容（3 项）：
1. **SecretsManager 密钥存储审计与治理（安全与合规维度）**：文件头自述缺口「Keys stored in UserDefaults are NOT encrypted at rest on disk; for production, switch to Keychain by setting useKeychain = true」——全仓密钥生命周期盘点分类：存储介质（20 个 APIService 全经 SecretsManager 单一入口（deepseek/openWeather/kuaidi100/slack/github/rss/mijia/homeAssistant/ssh/bilibili/opencodeGo/beecount 等），默认 UserDefaults 明文落盘；Keychain 代码完整但默认关闭且原实现 SecItemAdd 返回值被忽略=静默失败；AppSettings 10 处同键 @UserDefault 平行定义=死代码旁路（全仓零引用）；items.json 内嵌 api_key/apiKey 为 weather/deepseekBalance/usage 设计内配置）；泄漏面（日志/打印输出密钥全仓 0 命中；detectHardcodedKeys 原实现 0 调用点死代码且覆盖窄（仅 "api 前缀）+snippet 直接截取原行 60 字符含明文值=泄漏面→覆盖扩展 12 种 secret 形态键（apiKey/api_key/APIKey/apikey/token/secret/password/cookie/pat/authorization/x-api-key/credential 大小写不敏感）+snippet 值掩码 \*\*\*+精确行号；异常上报 detail 为服务端响应体不含请求密钥；SettingsSync 不导出服务密钥）；传输方式（DeepSeek/Slack/GitHub/RSS/HA/BeeCount 全部 Authorization Bearer header ✅；Bilibili/OpenCodeGo Cookie header ✅；OpenWeather appid query string 与快递100 key/sign POST body 为 vendor API 强制契约登记不改）；ATS 例外域 6 个（163.com 歌词搜索 HTTP 无鉴权/gtimg.cn 腾讯 CDN/qq.com/localhost RSS 开发服务器/sinajs.cn 历史遗留零引用/weather.com.cn 中国天气 HTTP）全部无鉴权公开端点，密钥请求全走 HTTPS/header，配置合理无需改动；**Keychain 治理评估**：切换机制可行且已完整实施（读穿回退+迁移+回退迁移+SecItem 状态检查+测试钩子），但默认值保持 false 不翻转——① Debug（77R6HZNK93）与 Release（D6D8BR2QNB）不同 DEVELOPMENT_TEAM，Keychain 条目 ACL 绑定签名 designated requirement，跨配置存在「另一配置读不到本配置写入条目」风险；② hosted 单测共享真实钥匙串+CI CODE_SIGNING_ALLOWED=NO，翻转默认会污染/无法访问；③ 翻转前需先统一签名身份（决策门登记），`useKeychain = true` 一行可开；**发现并根因修复真实问题 7 处**：① clear() 只清活动后端（Keychain 模式清不掉 UserDefaults 明文副本，回退后密钥复活）→ 双后端全清；② useKeychain=true 无存量迁移（现有用户密钥不可见）→ retrieve 读穿 UserDefaults 旧值+迁移+删明文副本；③ useKeychain=false 无回退读穿（曾切 Keychain 用户切回丢密钥）→ retrieve 反向迁移 Keychain 存量；④ store() 写活动后端不删另一后端（双写副本/陈旧值复活）→ 单一权威（写 Keychain 删 Defaults 副本/写 Defaults 删 Keychain 副本）；⑤ keychainStore 忽略 SecItemAdd 状态（写失败静默丢密钥）→ 状态检查+失败降级 UserDefaults+AppLog.warn+空串双后端清；⑥ detectHardcodedKeys 死代码+覆盖窄+snippet 含明文值 → 覆盖扩展 12 种形态键+值掩码 \*\*\*+精确行号；⑦ AppSettings 10 处同键 @UserDefault 死代码旁路（绕过单一入口）→ 删除（仅保留有引用的 deepseekModel/rssProvider）；新增契约测试 SecretsManagerContractTests.swift 13 用例（读写对称×2（双后端往返）+ 迁移×3（存量迁移删副本/写失败降级不丢/Keychain 写删 Defaults 副本）+ 回退×2（回退读穿反向迁移/Defaults 写删 Keychain 副本）+ 清除×2（双后端全清/空串清双后端）+ 检测×4（12 种形态键命中/空值非 secret 不误报/snippet 掩码脱敏/精确行号），沿用 SettingsSync.itemsJSONPathOverride 同型测试钩子 SecretsManager.defaultsOverride/keychainOverride（生产恒 nil 走真实后端，setUp/tearDown 复位不触碰真实存储），红（14 failures：迁移/回退/清除/单一权威/检测覆盖/掩码全红）→ 绿（13/13）双跑实证未放宽断言）；462 用例实证（449 基线 + 新增 13 零偏差，95.8s）0 失败（金丝雀 StockMarketHoursTests 16 / WidgetLeakTests 30 / RegistryReconciliationTests 6 / ItemTypeDecodeRegistryTests 173 / WriteSideContractTests 6 / SecretsManagerContractTests 13 全绿）；
2. **锚点巡检收口复跑接入保持**：连续第二十一轮 PASS 72/ERROR 0；
3. **工程版本号对齐**：Info.plist 0.42/467 → 0.43/468。

---

## 六、未虚构声明

本报告全部实证数据（行号、计数、tag 列表、巡检结果）均为本轮实时 grep / python / git / 脚本执行所得；README v0.44 条目内容全部摘自 iteration-log 第 43 轮实证记录（父收口段 :1679、t_d205d08d :1689-1697、t_0a46b5f7 :1683-1688、t_16024e56 :1698-1703），无任何虚构、推断或转写自他处的数字。

---

## 七、风险点

1. **README TODO 区行号位移（:389 → :399，+10）**：本轮 v0.44 条目在更新日志区置顶插入 10 行，README 更新日志区及之后的全部行号整体后移 +10——剪贴板 TODO 勾选项由 :389 → :399（本轮实测 :399；:389 为第 43 轮 B 卡提交 fc27dfd 后的实际位置，第 43 轮记录已按提交后状态登记）；Swift 源码行号（BarItemFactory.swift:212 / ItemsParsing.swift:358）不受影响，连续第十四轮零新漂移。后续轮次引用 README 更新日志区/TODO 区行号时以「改动后复测」为准（同第 31~43 轮惯例）。
2. **0.44/469 待收口**：日志最高条目 v0.44 与 Info.plist 0.43/468 存在一档差（既定惯例），须父任务收口时落地升号，本卡未擅改。
3. **README 超长行（1500+ 字符）**：read_file 工具将其误判为 binary 无法直接读取，本轮全部通过 terminal sed/grep 读取与 python 定点修改完成。
4. **迭代轮次口径（第 43 轮=功能/优化迭代第 31 轮，第 44 轮=第 32 轮）**：README v0.44 条目「承接第 43 轮」与 iteration-log 第 44 轮章节头「功能/优化迭代第 32 轮」为两套计数（轮次 vs 迭代序号），与第 31~43 轮既有惯例一致。
