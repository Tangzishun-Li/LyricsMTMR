# 验证报告_第43轮_SecretsManager密钥存储审计与治理

- 轮次：第 43 轮（功能/优化迭代第 31 轮）子任务 A
- 分支：r43/secrets（worktree `.worktrees/round43-A`，基于父分支预建头 446a35f = main@0860783 同点+1）
- 维度：安全与合规 — SecretsManager 密钥存储审计与 Keychain 治理
- 日期：2026-08-15
- 提交：本卡 commit（未 push，父任务收口统一推送）

---

## 一、审计：全仓密钥生命周期盘点

### 1.1 存储介质分类（20 个 APIService 全部经 SecretsManager 单一入口）

| 类别 | 位置 | 说明 |
|---|---|---|
| UserDefaults 明文落盘（默认） | `SecretsManager.swift:176 useKeychain=false`、`:237 store()`、`:210 retrieve()` | 全部 20 个服务密钥默认明文存 `com.lyricsmtmr.services.*`，文件头自述「NOT encrypted at rest on disk」 |
| Keychain（未启用） | `SecretsManager.swift:812 keychainStore` / `:828 keychainRetrieve` / `:845 keychainDelete` | 代码完整但默认关闭；原实现 `SecItemAdd` 返回值被忽略（静默失败）|
| 平行 UserDefaults 定义（死代码，已删） | `AppSettings.swift` 原 :174-238 区间 10 处 @UserDefault | 同键平行旁路：未来任何代码误用 `AppSettings.deepseekAPIKey` 即绕过 SecretsManager（绕过 Keychain 迁移）——grep 实证全仓零引用后删除 |
| items.json 配置内嵌密钥（设计内） | `ItemsParsing.swift:302/:319` weather/deepseekBalance 携带 `api_key`/`apiKey`，`:402/:443` CodingKeys，`:714/:775/:1145` decode | 「JSON 配置优先」是既有设计（UsageBarItem:139/DeepseekBalanceBarItem:24 同款回退），detectHardcodedKeys 用于发现这类嵌入 |

### 1.2 密钥传输方式（query string vs header）

| 服务 | 传输方式 | 位置 | 结论 |
|---|---|---|---|
| DeepSeek | `Authorization: Bearer` | SecretsManager:293 / UsageBarItem:144 / DeepseekBalanceBarItem:75 / WordLookup:62 / AiSelectedText:91 | ✅ header |
| OpenWeather | **query string `appid=`** | WeatherBarItem:176 / SecretsManager:348 | ⚠️ OpenWeatherMap 官方 API 强制 query 传参，无 header 替代——vendor 契约，非缺陷（登记不改）|
| 快递100 | POST body `customer/key/sign` | PackageTracker:39 | ⚠️ vendor 契约（sign=md5 校验），非 query string 泄漏（登记不改）|
| Slack / GitHub / RSS / HA / BeeCount | `Authorization: Bearer` | SlackUnread:32 / CiPipeline:33 / RssUnread:118,126,146 / HomekitScene:69,95 / SecretsManager:595,676 | ✅ header |
| Bilibili / OpenCodeGo | `Cookie` header | BilibiliFeed:33 / OpenCodeGoUsageBarItem:205 | ✅ header |

### 1.3 泄漏面（日志/打印/配置导出/异常上报）

| 泄漏面 | 结论 |
|---|---|
| 日志/打印输出密钥 | grep 全仓实证 0 命中：AppLog 全部调用点无密钥入参；WeatherBarItem 仅 print 错误对象；YandexWeatherBarItem:177 print 的 URL 无密钥（仅坐标）|
| detectHardcodedKeys 原实现 | ① 全仓 0 调用点（死代码——「Detection of hardcoded keys」自诩能力从未接线）；② 覆盖窄：仅匹配 `"api` 前缀小写、单行内冒号后非空引号串；③ **snippet 直接截取原始行前 60 字符含明文值**——若被日志/UI 使用即泄漏面 → 本轮修复 |
| 异常上报 | testConnection 错误 detail 为服务端响应体前 200 字符（不含请求密钥）；error.localizedDescription 不含 URL 中的 appid |
| 配置导出 | SettingsSync 仅写 items.json widget 配置，不导出服务密钥 |

### 1.4 ATS 例外域清单（Info.plist NSAppTransportSecurity :31-74）

| 域 | 用途 | 鉴权 | 结论 |
|---|---|---|---|
| 163.com | NetEase 歌词搜索 HTTP API（NetEaseProvider:98）| 无 | ✅ 无密钥经 HTTP |
| gtimg.cn | 腾讯 CDN 封面（QQMusicProvider:134）| 无 | ✅ |
| qq.com | QQ 音乐 API | 无 | ✅ |
| localhost | RSS 本地开发服务器（RSSTabView:619 / RssUnread:133）| 无 | ✅ |
| sinajs.cn | 新浪行情（历史遗留，当前代码零引用）| 无 | ✅ 可保留（保守不删）|
| weather.com.cn | 中国天气 HTTP（ChinaWeatherProvider:29-31）| 无 | ✅ |

结论：6 个例外域全部为无鉴权公开数据端点，密钥请求全部走 HTTPS/header，ATS 配置合理，无需改动。

---

## 二、Keychain 治理可行性评估

**结论：切换机制可行且已完整实施（迁移+回退+状态检查+测试钩子），但默认值保持 `useKeychain = false`，不翻转。**

评估依据（生产行为影响逐项）：

1. **现有用户存量密钥读取兼容**：原实现 `useKeychain=true` 时 retrieve 只看 Keychain——存量 UserDefaults 密钥直接「消失」。本轮实现读穿回退：Keychain 未命中 → 读 UserDefaults 旧值 → 迁移写入 Keychain 成功后删除明文副本（:210-216）。存量用户零感知。
2. **迁移路径**：`store()` 写 Keychain 成功后同步删 UserDefaults 副本（单一权威，:245-247）；`retrieve()` 读穿时同样迁移。
3. **回退策略**：`useKeychain=false` 时 UserDefaults 未命中 → 读 Keychain 存量并反向迁移回 UserDefaults（:221-228）——切回后存量无损恢复；`store()` 写 UserDefaults 时删 Keychain 陈旧副本（:255-257）。
4. **Keychain 无登录/无钥匙串场景**：`keychainStore` 检查 `SecItemAdd` 返回状态（:819，原实现静默忽略）——写失败降级 UserDefaults 并 AppLog.warn（:248-252），数据不丢。
5. **为什么不翻转默认值**：
   - `project.pbxproj` 实证 Debug 用 DEVELOPMENT_TEAM=77R6HZNK93（:1511）、Release 用 D6D8BR2QNB（:1543）——Keychain 条目 ACL 绑定签名 designated requirement，跨配置切换存在「另一配置读不到本配置写入条目」的真实风险；
   - hosted 单测（TEST_HOST 宿主 App 进程）若默认走真实 Keychain 会污染开发者登录钥匙串；CI `CODE_SIGNING_ALLOWED=NO` 无法访问钥匙串；
   - 结论：翻转前需先统一签名身份（B 卡/父任务决策项），本卡实现完整路径 + 契约测试覆盖，`useKeychain = true` 一行即可在生产开启。

---

## 三、真实问题修复（红→绿双跑实证，断言未放宽）

| # | 问题（原行为） | 根因修复 | 红→绿实证 |
|---|---|---|---|
| ① | `clear()` 只清活动后端（:192 原 `store("")`）——Keychain 模式清不掉 UserDefaults 明文副本，回退后密钥复活 | `clear()` 双后端全清（:262-265）| 红：testClearRemovesBothBackends 失败（明文残留）；绿：通过 |
| ② | `useKeychain=true` 无存量迁移——现有用户密钥不可见 | retrieve 读穿 UserDefaults + 迁移 + 删明文副本 | 红：testKeychainReadMigratesLegacyDefaults 3 断言失败；绿：通过 |
| ③ | `useKeychain=false` 无回退读穿——曾切 Keychain 的用户切回后密钥丢失 | retrieve 反向迁移 Keychain 存量 | 红：testRollbackReadsKeychainWhenDefaultsEmpty 3 断言失败；绿：通过 |
| ④ | `store()` 写活动后端不删另一后端——双写副本、陈旧值复活 | store 单一权威：写 Keychain 删 Defaults 副本 / 写 Defaults 删 Keychain 副本 | 红：testStoreWithKeychainRemovesDefaultsCopy + testStoreWithDefaultsRemovesKeychainCopy 失败；绿：通过 |
| ⑤ | `keychainStore` 忽略 `SecItemAdd` 状态——写失败静默丢密钥 | 检查状态，失败降级 UserDefaults + warn；`store("")` 双后端清 | 红：testStoreEmptyStringClearsBothBackends / testKeychainMigrationKeepsDefaultsWhenKeychainWriteFails 失败；绿：通过 |
| ⑥ | `detectHardcodedKeys` 死代码（全仓 0 调用）+ 覆盖窄（仅 `"api` 前缀）+ **snippet 含明文值**（泄漏面）| 覆盖扩展到 12 种 secret 形态键（apiKey/api_key/APIKey/apikey/token/secret/password/cookie/pat/authorization/x-api-key/credential，大小写不敏感）+ **snippet 值掩码 `***`** + 精确行号 | 红：testDetectHardcodedKeysCatchesSecretKeyVariants（仅命中 3 处）+ testDetectHardcodedKeysSnippetMasked（snippet 含明文）失败；绿：通过 |
| ⑦ | AppSettings 10 处同键 @UserDefault 平行定义（死代码旁路，绕过 SecretsManager 单一入口）| 删除（grep 实证全仓零引用；仅保留有引用的 deepseekModel/rssProvider）| 编译+全量回归实证无破坏 |

红跑记录：`/tmp/LyricsMTMR-dd-r43a-red`（-only-testing 新测试类）——**Executed 13 tests, with 14 failures**（9 个测试失败：迁移/回退/清除/单一权威/检测覆盖/掩码全部红）。
绿跑记录：`/tmp/LyricsMTMR-dd-r43a-green2`——**Executed 13 tests, with 0 failures**。同一组测试文件、同一组断言，仅修复实现，未放宽断言。

---

## 四、契约测试（新增 SecretsManagerContractTests.swift，13 用例）

| 用例 | 契约 | 对应修复 |
|---|---|---|
| testDefaultsStoreRetrieveRoundTrip | UserDefaults 后端读写对称 | 基线 |
| testKeychainStoreRetrieveRoundTrip | Keychain 后端读写对称 | 基线 |
| testKeychainReadMigratesLegacyDefaults | 存量迁移+删明文副本 | ② |
| testKeychainMigrationKeepsDefaultsWhenKeychainWriteFails | 写失败降级不丢数据 | ⑤ |
| testStoreWithKeychainRemovesDefaultsCopy | 单一权威（Keychain 写删 Defaults 副本）| ④ |
| testRollbackReadsKeychainWhenDefaultsEmpty | 回退读穿+反向迁移 | ③ |
| testStoreWithDefaultsRemovesKeychainCopy | 单一权威（Defaults 写删 Keychain 副本）| ④ |
| testClearRemovesBothBackends | 双后端全清 | ① |
| testStoreEmptyStringClearsBothBackends | 空串清双后端 | ⑤ |
| testDetectHardcodedKeysCatchesSecretKeyVariants | 12 种 secret 形态键命中 | ⑥ |
| testDetectHardcodedKeysIgnoresEmptyAndNonSecret | 空值/非 secret 不误报 | ⑥ |
| testDetectHardcodedKeysSnippetMasked | snippet 脱敏（不含明文值）| ⑥ |
| testDetectHardcodedKeysReportsLineNumbers | 精确行号 | ⑥ |

测试钩子：`SecretsManager.defaultsOverride`（注入 UserDefaults 套件）/ `SecretsManager.keychainOverride`（内存 Keychain 桩，KeychainBackend struct）——生产恒 nil 走真实后端，与 `SettingsSync.itemsJSONPathOverride`（第 42 轮 WriteSideContractTests）同型；`setUp`/`tearDown` 复位，不触碰真实 UserDefaults/真实钥匙串。
注册：`python3 LyricsMTMR/Scripts/add_files.py Tests:SecretsManagerContractTests.swift` → pbxproj 4 条目（PBXBuildFile C1FF2E2A… / PBXFileReference C1FE2E2A… / group child / Sources phase），git diff 实证在位。

---

## 五、全量回归实证

```
xcodebuild test -project LyricsMTMR.xcodeproj -scheme UnitTests -configuration Debug
  -derivedDataPath /tmp/LyricsMTMR-dd-r43a-test CODE_SIGNING_ALLOWED=NO

Executed 462 tests, with 0 failures (0 unexpected) in 95.8s
** TEST SUCCEEDED **
```

- 口径：**449 基线 + 13 新增 = 462，零偏差**（先清理旧 /tmp/LyricsMTMR-dd-* 防磁盘写满；caffeinate -i 防显示器休眠）
- 金丝雀：StockMarketHoursTests 16（含 2026/2027/Makeup2026 三锚点）✅ / WidgetLeakTests 30 ✅ / RegistryReconciliationTests 6 ✅ / ItemTypeDecodeRegistryTests 173 ✅ / WriteSideContractTests 6 ✅ / SecretsManagerContractTests 13 ✅

---

## 六、锚点巡检复跑

```
python3 scripts/anchor-patrol.py --quiet
PASS 72 / WARN 11 / INFO 5 / ERROR 0 — 退出码 0
```

本轮改动文件（SecretsManager.swift / AppSettings.swift / SecretsManagerContractTests.swift / 文档）均无锚点登记 → 零改动复跑确认；与第 42 轮收口基线逐项一致（WARN 11/INFO 5 全部 known 已登记项），连续第二十轮 0 ERROR。

---

## 七、文档同步表

| 文档 | 动作 |
|---|---|
| 本验证报告《验证报告_第43轮_SecretsManager密钥存储审计与治理.md》| 新建（本分支根目录）|
| iteration-log.md | 「## 第 43 轮」+「### 父任务」为父分支预建，本卡补建「### 子任务记录」小节头后追加本卡记录（标注「第 43 轮 / 子任务 A」，收口时父任务重组）|
| file-structure.zh.md | mindmap 第 7~42 轮 → 第 7~43 轮 + 本报告行（归位于验证报告区，无重复行）|
| scripts/anchor-patrol.py | 零改动复跑确认（PASS 72/ERROR 0）|

---

## 八、结论与遗留登记

**结论**：全仓密钥生命周期审计完成——20 个 APIService 全部经 SecretsManager 单一入口，默认 UserDefaults 明文落盘（自述缺口）；泄漏面 0 处日志输出、ATS 6 域全部合理、query-string 密钥仅 OpenWeather/快递100 两处 vendor 契约；**真实问题 7 处全部根因修复**（clear 双后端全清/存量迁移/回退迁移/单一权威/SecItem 状态检查/检测强化+掩码/死代码旁路清理），红（14 failures）→绿（13/13）双跑实证未放宽断言；**全量 462 用例 0 失败**（449 基线+13 新增）；锚点巡检 PASS 72/ERROR 0（连续第二十轮）。

**遗留登记**：
1. `useKeychain=true` 生产翻转决策门：需先统一 Debug/Release 签名身份（当前 77R6HZNK93 vs D6D8BR2QNB），翻转后 hosted 单测需全局注入 keychainOverride 防污染——本卡实现完整路径 + 13 用例覆盖，一行可开；
2. detectHardcodedKeys 仍为审计工具（无自动接线）：items.json 内嵌 `api_key`/`apiKey` 是 weather/deepseekBalance/usage 的设计内配置，自动告警会误报——登记为「工具 + 契约测试覆盖」定位；
3. AppSettings.deepseekModel / rssProvider 保留（有引用），其余服务键统一由 SecretsManager 托管；
4. 内存修复真机冒烟 3 项挂账延续（第 8/17~43 轮同口径）；
5. 测试钩子 defaultsOverride/keychainOverride 保持 @testable 内部可见不进生产路径（同 itemsJSONPathOverride 先例）。
