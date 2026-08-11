# LyricsMTMR 自迭代规划（iteration-plan）

## ⏳ 待办区（置顶）

> 时间敏感事项，完成一项划掉一项；流程与数据源详见 `docs/maintenance-notes.md`。

- [ ] **ITER-14 核对提醒（2026-11）：国办发布《2027 年部分节假日安排》通知后，核对并更新
      `StockBarItem.aShareHolidays` / `aShareMakeupDates` 的 2027 预估段**（
      `LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift:388` 起；2027 节日日期为农历/公历确定值，
      连休窗口与补班日为预估）。
      检查点清单：
      - 春节连休窗口与补班日（当前预估 2/5(五)除夕 ~ 2/12(五)初七，共 8 天）；
      - 端午连休窗口与补班日（当前预估 6/7(一) ~ 6/9(三)）；
      - 中秋连休窗口与补班日（当前预估 9/13(一) ~ 9/15(三)）；
      - 其余节日窗口是否与官方通知一致（元旦 / 清明 / 劳动 / 国庆）。
      改表后跑 `MTMRTests` 验证（ITER-8 表驱动断言自动覆盖两表）。

> 由 review-agent t_d5f6f8d4 在「19 项 OPT 全部合并进 main」（t_c5bc1429）之后，通读
> 本次合并 diff（8641071..e9c7502，10 个 merge commit、15 文件、+538/-100）后产出。
> 目标：不是再跑一遍测试，而是从 UI 设计 / 交互逻辑 / 功能改进 / 代码一致性角度
> 寻找下一轮可落地优化，并记录本轮 review 直接修复的问题。

---

## 〇、本轮 review 直接修复（已合并 / 合并中）

### FIX-1 镜像窗快照类 item 永久冻结 + 指纹变化双重重建（OPT-17 回归）✅ PR #19

**现象**：`TouchBarMirrorWindowController.syncFromTouchBar()`（OPT-17 增量同步）中，
快照类 item（AppScrubber / 音量 / 亮度 / 自定义视图等）`fingerprint(of:)` 返回 nil，
原代码 `guard let fingerprint = fingerprint(of: item) else { continue }` **直接跳过重建**，
而这些视图的内容是 `snapshot()` 截的位图 —— 意味着镜像窗里 Dock 切换、音量拖动、
亮度变化永远不会反映出来（永远冻结在首次渲染）。与注释「快照类：每次刷新」自相矛盾，
也回归了 OPT-17 之前每 0.1s 全量重建的旧行为。

**附带问题**：指纹变化分支用 `makeItemView(for:)` 重建，但该方法**不设置 view.identifier**，
下一轮 0.1s 同步时 `view(existing, matches:)` 按 identifier 比对失败 → 走 else 分支
→ 用 `makeView(for:)` 再重建一次（这次才带 identifier）。即每次内容变化实际重建两次。

**修复**（PR #19，build ✅ / test 待跑）：
- 指纹为 nil → 每次同步重建该单个视图（与旧行为一致，不连累其他视图），并清理其指纹缓存条目；
- 指纹变化 → 改用 `makeView(for: .item(item))`，重建即带 identifier，下轮直接命中 matches，消除双重重建。

---

## 一、下一轮优化建议（按优先级）

### ITER-1 【高】Sparkle 2.1 appcast 签名缺口 —— 自动更新大概率不可用（OPT-12 遗留）

**现状**：仓库内嵌 Sparkle **2.1.0**。Sparkle 2 起**移除了 DSA 支持**，只认 EdDSA
（Info.plist 的 `SUPublicEDKey` + appcast 的 `sparkle:edSignature`）。但当前：
- `Info.plist` 仍是 `SUPublicDSAKeyFile = dsa_pub.pem`（Sparkle 1.x 风格，2.1 不再读取）；
- `.github/workflows/publish.yml` 生成的 `appcast.xml` **完全没有签名字段**（无 dsaSignature 也无 edSignature）。

后果：带公钥配置的 Sparkle 2 会拒绝/无法校验未签名更新 —— 即 OPT-12 改完更新源后，
用户点击检查更新大概率报「无法验证更新」。**建议**：
1. 用 Sparkle 工具链生成 Ed25519 密钥对（`generate_keys` / `sign_update`）；
2. 把公钥 base64 写入 `Info.plist` 的 `SUPublicEDKey`；
3. publish.yml 增加签名步骤（私钥放 GitHub Secrets），给 `<enclosure>` 加 `sparkle:edSignature`；
4. 若暂不打算签名，则删掉 `SUPublicDSAKeyFile` 并接受「未签名更新」降级（不推荐）。

**验证方式**：本地用 `Sparkle/bin/sign_update` 对构建产物签名后，跑一次 `SPUUpdater` 检查。

### ITER-2 【中】OPT-8 内存警告未覆盖 OPT-18 歌词 LRU —— 清理面不一致

`AppDelegate.applicationDidReceiveMemoryWarning` 清了 CoverCache、URLCache、设置页缓存，
但**没清** `NetEaseProvider.lyricsCache`（OPT-18 新增，32 条上限）。虽然容量有界、
单条歌词不过几十 KB，与「内存压力兜底」的语义不一致。建议给 `LyricsLRUCache` 加
`clear()` 并在此处调用。改动 ~10 行，低风险。

### ITER-3 【中】镜像窗快照类 item 每 0.1s 全量位图重渲染 —— 节流

FIX-1 恢复正确性后，快照类 item（scrubber/音量/亮度等，通常 1~3 个）每 0.1s 都做一次
`layer.render(in:)` 位图截取（`snapshot()`）。这类内容变化频率远低于 10Hz：
- AppScrubber：只有前台 App 变化时才变；
- 音量/亮度：拖动或按键时才变。

建议：快照类 item 降频（如每 5 个 tick ≈ 0.5s 刷新一次），或对源视图做轻量
「内容变化探针」（比较 `view.frame` + 一个 cheap hash），无变化则跳过重截。
收益：镜像窗开启时 CPU 进一步下降；风险低（最坏情况快照延迟几百 ms）。

### ITER-4 【中】A 股法定节假日未纳入休市判断（OPT-11 边界）

`StockBarItem.isMarketOpen()` 只判断「工作日 + 时段」。国庆/春节/中秋等**法定假日
落在工作日**时，会误判为交易时段，10s 轮询照跑（休市日行情恒定，纯浪费）。
建议：内置一张小型 A 股休市日表（或每年更新一次），在 `isMarketOpen` 前置判断。
数据源简单（如公开交易日历 CSV），改动集中在 `StockBarItem.swift`。

### ITER-5 【低】examples/presets/items.json 内存组件 awk 死代码

OPT-10 改动后：`ps -A -o %cpu,%mem | awk '{c+=$1;m+=$2}END{printf "%d%%",m}'` —
`c` 求和了但从未输出（死代码），且 `%d` 是截断而非四舍五入。建议输出 CPU 或删除 `c`。
纯示例文件，零风险。

### ITER-6 【低】为新增纯逻辑补单元测试（代码一致性/防回归）

项目已有 UnitTests scheme（4 个测试文件）。OPT-17/18/11/4 新增的纯逻辑——
`ItemFingerprint` 相等性、`LyricsLRUCache` 淘汰顺序、`isMarketOpen` 边界、`SettingsTabCache`
LRU 淘汰 —— 均可低成本单测，防止下轮优化误伤。建议按 OPT 编号补一组
`NetEaseLRUCacheTests` / `MirrorFingerprintTests` / `StockMarketHoursTests`。

---

## 二、本轮 review 确认无问题（排除清单，避免重复改）

| 项 | 结论 |
|---|---|
| KaraokeLabel `intrinsicContentSize` / `fullTextWidth` 改走 ctFrame 缓存 | ✅ 等价：path 即 `suggestFrameSize` 结果，无精度损失 |
| OPT-5 marquee 复用守卫（lineIndex + lyricsId） | ✅ 同行复用、行切换重建，逻辑闭合 |
| OPT-13 切应用快速路径 `!appDidChange && touchBarIsBuilt()` | ✅ 快速路径只跳过无必要的重建，preset 重载仍走 prepareTouchBar |
| OPT-1 关窗释放（windowWillClose 回调置 nil） | ✅ 已按计划改动点②实现，PR #12 有注释说明 |
| OPT-3 blur 静态化（opacity 移到 blur 之后） | ✅ 高斯模糊线性，数学等价 |
| OPT-7 删 synchronize() | ✅ 系统自动持久化 |
| OPT-19 os.Logger 迁移 | ✅ 等级映射正确，debug 仍 #if DEBUG 裁剪 |
| OPT-9 build.sh Debug→Release | ✅ 与发布流程一致 |
| OPT-10 脚本轮询（%cpu,%mem）| ⚠️ 见 ITER-5（示例文件死代码，不影响运行） |

---

## 三、建议的实施批次

- **Batch 1（1~2 张卡）**：ITER-1 Sparkle 签名（功能完整性，需密钥生成 + CI 改动，可先出方案再实施）；
- **Batch 2（1 张卡）**：ITER-2 + ITER-3（内存清理一致性 + 镜像窗节流，都是低风险小改）；
- **Batch 3（1 张卡，可选）**：ITER-4 交易日历 + ITER-6 单测；
- **顺手**：ITER-5 示例清理。

每张卡完成后跑 `xcodebuild build`（Debug）+ UnitTests，涉及 CI 的卡（ITER-1）需真机/本地验证一次检查更新流程。

---

## 四、第二轮审查（ITER-1~6 全部合并后，由 review-agent t_ba973cf0 产出）

> 在 ITER-1~6（PR #20~#24，含补合的 ITER-6 #24）全部并入 main 之后，通读合并 diff
> （fd3daeb..c69fabb，5 个 PR、15 文件、+583/-61），并对 ITER-1 签名做了真实端到端验证。

### 〇、本轮 review 直接修复（已合并）

- **注释/文档一致性（PR #25）**：ITER-3 节流落地后，`TouchBarMirrorWindowController.swift`
  仍有 2 处过时注释写「每次同步都刷新」（ItemFingerprint 枚举文档 :199-200、`fingerprint(of:)`
  :264），与「每 5 tick ≈ 0.5s 重建」矛盾 —— 已改为指向 ITER-3 节流语义；
  `file-structure.zh.md:83` 单测计数 16 → 56（ITER-6 新增 38 个用例后）。

### 一、已排除候选清单（本轮确认无问题，避免重复改）

| 项 | 结论 | 证据 |
|---|---|---|
| ITER-1 EdDSA 签名流程可用性 | ✅ 端到端验证通过 | `Info.plist:113` SUPublicEDKey 与 v1.0.0 appcast.xml 的 `sparkle:edSignature` 验签一致（Python Ed25519 verify PASS）；`publish.yml:36-53` 的 sign_update CLI 用法与 Sparkle 2.1.0 官方工具实测一致（96B 私钥文件 = 64B 私钥+32B 公钥，`-f` 与 `--verify` 参数正确）；SPARKLE_PRIVATE_KEY secret 已配置（gh secret list 确认） |
| ITER-2 内存警告清歌词 LRU | ✅ 语义一致、线程安全 | `NetEaseProvider.swift:80-87` clear() 走 serial queue；`AppDelegate.swift:74` 调用点在 CoverCache/URLCache 清理旁；容量守卫 `max(1, capacity)` 与测试断言一致 |
| ITER-3 节流与 FIX-1 兼容 | ✅ 无冻结回归 | `TouchBarMirrorWindowController.swift:159` 的 `if !snapshotDue { continue }` 只作用于快照分支（fingerprint 为 nil 的 item），指纹 item 不受影响；`liveIdentifiers` 插入在 continue 之前（:145），指纹缓存清理不误伤；最坏快照延迟 0.5s，与 ITER-3 预期一致 |
| ITER-4 节假日表准确性（抽 2-3 个日期复核 → 全表复核） | ✅ 2026 官方表逐日核对通过 | 元旦 1/1(四)~1/3(六)+1/4(日)补班；春节 2/15(日)~2/23(一)+2/14(六)、2/28(六)补班；清明 4/4(六)~4/6(一)；劳动 5/1(五)~5/5(二)+5/9(六)补班；端午 6/19(五)~6/21(日)；中秋 9/25(五)~9/27(日)；国庆 10/1(四)~10/7(三)+9/20(日)、10/10(六)补班 —— 星期、窗口、补班日与国办发明电〔2025〕7 号完全一致（Python 校验星期）。2027 表已明确标注「预估、待国办通知核对」，注释含数据来源与更新机制 |
| ITER-5 items.json awk 清理 | ✅ 与建议一致 | `examples/presets/items.json:210` 删除死代码 `c`、`%d`→`%.0f` 四舍五入 |
| ITER-6 单测可见性调整 | ✅ 无逻辑变更 | 3 处 private→internal（`TouchBarMirrorWindowController.swift:203`、`NetEaseProvider.swift:37`、`UnifiedSettingsWindowController.swift:937`）+ `isMarketOpen` 抽 static（`StockBarItem.swift:425-438`），均保留实例入口；56 用例 0 失败 |
| dsa_pub.pem 残留 | ✅ 清理干净 | pbxproj 0 引用、文件已删、docs 已同步；仅 gitignored 构建产物（.build/、Release/）含旧 key，无影响 |

### 二、下一轮建议（ITER-7+，按优先级）

- **ITER-7 【高】2027 节假日表核对 + 后续年份滚动维护机制**
  现状：`StockBarItem.swift:75-118` 内置表只到 2027 且 2027 为预估。2026-11 国办发布
  2027 通知后须核对更新；2028+ 完全无表，工作日落在法定假日时会误判为交易日。
  建议：表数据抽成独立资源（JSON/plist）+ 每年 11 月核对一次的维护备注（或 CI 提醒）。
  风险：低（纯数据），但需要人跟进，时间敏感。

- **ITER-8 【中】节假日表与测试数据源合一**
  现状：`StockMarketHoursTests.swift` 的锚点日期（如「劳动 5/1(五)~5/5(二)」）从表注释
  复制，两处漂移风险。建议：单测从 `StockBarItem` 的同一常量生成断言（或暴露 internal
  只读表）。风险：低。

- **ITER-9 【中】镜像窗节流参数按场景自适应**
  现状：`TouchBarMirrorWindowController.swift:17` 固定 5 tick（0.5s）。快照 item 多时
  仍每 0.5s 全截一次。建议：按快照 item 数量动态调整（1 个 → 5 tick，3 个以上 → 10 tick），
  或对 AppScrubber 用 `NSWorkspace.sharedNotificationCenter` 前台 App 变化事件驱动刷新
  （事件驱动后节流可更激进）。风险：低-中（涉及 FIX-1 语义，需保留「绝不冻结」底线）。

- **ITER-10 【低】publish.yml 签名自检增强**
  现状：`publish.yml:52-53` 的 `--verify` 只验证签名与 keyfile 自身配套，未交叉校验
  `Info.plist` 的 SUPublicEDKey 与 secret 是否同源 —— 若 key 轮换后两者不同步，CI 仍绿
  但客户端验签失败。建议：workflow 中从归档产物 Info.plist 提取 SUPublicEDKey 与
  keyfile 内公钥比对。风险：低。

- **ITER-11 【低】syncTick 生命周期**
  现状：`TouchBarMirrorWindowController.swift:16` syncTick 只增不减，hide/show 之间
  不归零（无功能影响，但快照相位不可预期）。建议：show() 时归零。风险：无。

### 三、实施批次建议

- **Batch 1（1 张卡）**：ITER-7 节假日表核对 + 外置化（数据维护，先出方案）；
- **Batch 2（1 张卡）**：ITER-8 + ITER-9（单测数据源合一 + 节流自适应，代码小改）；
- **Batch 3（可选）**：ITER-10 + ITER-11（CI 自检增强 + syncTick 归零，各 <20 行）。


---

## 五、第三轮审查（ITER-7~11 全部合并后，由 review-agent t_9e31a058 产出）

> 在 ITER-7~11（PR #26~#28）全部并入 main 之后，通读合并 diff
> （63c59bf..d0b668d，3 个 squash commit、4 文件、+150/-49），并对 ITER-10
> 密钥格式做了官方源码 + 工具链端到端实证（Sparkle 2.1.0 generate_keys/sign_update 源码
> + /tmp/sparkle210 实测）。

### 〇、本轮 review 直接修复（已合并）

- **注释/文档一致性（PR #29，CI 全绿后合入）**：ITER-8 后 `file-structure.zh.md:83`
  单测计数仍写 56（实际 57，ITER-8 新增 `testHolidayAndMakeupTablesDisjoint` 守卫用例）；
  `TouchBarMirrorWindowController.swift:287` `fingerprint(of:)` 文档注释仍写
  「按 ITER-3 节流重建」，与枚举级注释（:221 已写 ITER-3 + ITER-9）及自适应间隔
  5/7/10 tick 不一致 —— 均已修正（与第二轮 PR #25 同类问题，无逻辑改动）。

### 一、已排除候选清单（本轮确认无问题，避免重复改）

| 项 | 结论 | 证据 |
|---|---|---|
| ITER-7 数据源重构后 isMarketOpen 行为与 ITER-4 表一致 | ✅ 集合逐字节一致 + 14 日期抽查 | `StockBarItem.swift` 65 节假日 + 12 补班日期集合 63c59bf→d0b668d 完全相同（仅改名 aShareClosedDates→aShareHolidays + 注释，git 提取比对）；isMarketOpen 函数 diff 仅 1 行改名；抽查 2026-02-14/02-28/05-09/10-10 补班周六开市、02-23 假期窗口末休市、02-24/05-06 节后首日开市、04-26(日) 非补班休市（国办通知确无此补班）、01-04 补班日 09:00/09:15/12:00/15:00 时段边界 —— 全部与国办发明电〔2025〕7 号一致 |
| ITER-9 自适应节流与 FIX-1/ITER-3 语义兼容 | ✅ | 0-1 个快照 item → 5 tick（:22-27，原值行为不变）；snapshotCount 仅统计 fingerprint(of:)==nil 的 item（:141-143，纯类型检查无副作用）；快照分支 `if !snapshotDue { continue }` 语义未动，FIX-1「绝不永久冻结」底线保留；间隔按每 tick 计数重算，切换下一 tick 生效，无相位漂移问题 |
| ITER-11 syncTick 归零 | ✅ | `show()` 顶部 :44 归零，先于 window!=nil 早退分支 → 每次显示相位可预期；首刷时刻 = 显示后第 interval 个 tick（0.5/0.7/1.0s），与注释一致 |
| ITER-10 交叉自检（key 轮换场景） | ✅ 官方源码+工具链端到端实证 | Sparkle 2.1.0 `generate_keys/main.swift`（-x 导出 = base64(私钥 64B + 公钥 32B)，私钥 = scalar(32)+零(32)，由 orlp/ed25519@7fa6712 keypair.c 实证）+ `sign_update/main.swift`（96B 校验、[0..<64]/[64...] 拆分）；`base64 -d \| tail -c 32 \| base64` 实测提取公钥 == SUPublicEDKey 值；sign_update -f 签名 + --verify 往返通过；Info.plist 公钥与 keyfile 不同源 → exit 1（fail-closed，防密钥轮换后 CI 绿但客户端验签失败） |
| ITER-8 表驱动测试 | ✅ 设计取舍明确 | 表全量遍历断言（休市/补班）+ 窗口末次日后置 + 两表不相交守卫均为真实逻辑断言；代价：表内容不再有独立锚点校验（测试与数据源同源），见 ITER-12 |

### 二、下一轮建议（ITER-12+，按优先级）

- **ITER-12 【低】节假日表恢复少量官方锚点断言（独立数据校验）**
  现状：ITER-8 后 `StockMarketHoursTests` 全部从表生成断言，表内日期若被误改
  （如手滑把 2026-03-15 加进 aShareHolidays）测试仍绿 —— 表数据正确性只剩人工核对。
  建议：保留表驱动遍历的同时，恢复 5-8 个国办通知官方锚点（如 2026-01-01、
  2026-02-23、2026-04-06、2026-05-01/05-09、2026-10-10）做固定断言，作为表内容的
  独立「金丝雀」。风险：低；改一处测试文件。

- **ITER-13 【低】publish.yml 自检报错信息增强**
  现状：ITER-10 校验失败时若 `base64 -d` 失败（如 secret 误存 PEM 格式），
  `KEY_PUB64` 为空，报「SUPublicEDKey() != ...()」看不出原因。
  建议：`base64 -d` 失败时单独报「SPARKLE_PRIVATE_KEY 不是 base64(96B) 格式」。
  风险：无。

- **ITER-14 【低】2027 节假日表维护提醒机制**
  现状：2027 表为预估，注释已写明待国办 2026-11 通知核对，但无机制提醒。
  建议：2026-11 前后在 docs 置顶待办或加 CI 定时提醒（需人跟进，时间敏感）。
  风险：无（纯流程）。

- **ITER-15 【中·可选】AppScrubber 事件驱动刷新（ITER-9 深化）**
  ITER-9 按数量自适应后快照最坏 ~1s 延迟仍存在。可对 AppScrubber 用
  `NSWorkspace.sharedNotificationCenter` 前台 App 变化事件驱动刷新，事件触发时
  跳过节流直接重建，其余快照 item 维持节流。风险：中（涉及 FIX-1 语义边界，
  需保留「绝不冻结」底线），建议镜像窗使用场景确认有感知后再做。

### 三、实施批次建议

- **Batch 1（1 张卡）**：ITER-12（测试金丝雀，纯测试文件小改）；
- **Batch 2（1 张卡）**：ITER-13（CI 脚本，<10 行）；
- **Batch 3（可选）**：ITER-14（流程提醒）、ITER-15（事件驱动，需先观察镜像窗实际使用）。

---

## 六、第四轮审查（ITER-12~14 全部合并后，由 review-agent t_5ea6d239 产出）

> 在 ITER-12~14（PR #30~#32，squash 合并 6fa6f7a/730119f/99a88d0）全部并入 main 之后，
> 通读合并 diff（2083acc..99a88d0，3 个 squash commit、4 文件、+336），并对 ITER-12
> 金丝雀锚点逐日核验（国办发明电〔2025〕7 号）、ITER-13 脚本三分支在 macOS runner
> 上的行为做了实测复验（macOS `base64 -d` 兼容性）。

### 〇、本轮 review 直接修复（PR #33，CI 全绿后合入）

- **ITER-12 金丝雀锚点覆盖补齐（国庆 + 4 个官方补班日）**：原金丝雀只覆盖 6 个节日
  窗口端点与 2 个补班日——**国庆（10/1~10/7，全年最长 7 天窗口）无锚点**，1/4（元旦）、
  2/14、2/28（春节）、9/20（国庆）四个官方补班日亦缺失：这些日期若被误删出
  `aShareHolidays`/`aShareMakeupDates`，表驱动遍历（断言源自表本身）与金丝雀都测不出，
  与 ITER-12 注释声称的「表若被误改，锚点立即失败」相悖。已补全为 8 个节日锚点
  （7 个官方节日窗口全覆盖）+ 6 个补班锚点（`StockMarketHoursTests.swift:145-163`），
  全部日期经 Python 复核星期与国办发明电〔2025〕7 号一致。
- **file-structure.zh.md 单测计数两处过时**：`:50`「构建 + 16 个单元测试」为建仓时旧值
  （ITER-6 后实际 59）；`:83`「57 个用例」未随 ITER-12 新增 2 用例更新（实际 59）——
  已改为 59（与 xcodebuild 实测一致）。
- **maintenance-notes.md「若后续 ITER-12 金丝雀落地」条件句过时**：ITER-12 已随本轮
  合并落地，改为现状说明（已覆盖 2026 全部节日窗口端点与补班日）+ 新年份核对落表后
  须同步补充金丝雀锚点的维护要求。

### 一、已排除候选清单（本轮确认无问题，避免重复改）

| 项 | 结论 | 证据 |
|---|---|---|
| ITER-13 脚本三分支正确性（正常 / PEM / 长度错） | ✅ | publish.yml `runs-on: macos-latest`（:12）；macOS `base64 -d` 实测可用（本地 rc=0，兼容）；KEY_LEN 检查（:63-67）同时覆盖「解码失败→0 字节」与「长度≠96B」两条错误路径，置于 sign_update 之前 fail-closed；ITER-13 卡已用真实 sign_update 2.1.0 + 真实 Ed25519 密钥逐字跑通三场景 |
| ITER-12 金丝雀锚点与表/官方通知一致 | ✅ 逐日核验 | 8 个原锚点日期全部存在于两表（`StockBarItem.swift:377-387` / `:406-411`），Python 复核星期与断言消息标注逐一吻合（四/一/一/五/五/五/六/六），与国办发明电〔2025〕7 号一致（第二、三轮已全表逐日核对） |
| ITER-14 文档行号引用 | ✅ | 待办区「2027 预估段 `StockBarItem.swift:388` 起」= 实际 2027 段注释行（:388）；maintenance-notes 引用 :369-370（2026 来源注释）、:375-399（aShareHolidays）、:404-419（aShareMakeupDates）全部与实际行号吻合 |
| 休市日行情轮询浪费 | ✅ 已解决 | `StockBarItem.swift:81-85` `effectiveRefreshInterval`：休市时段自动降频至 ≥60s（OPT-11），无需再改 |
| 2028 年节假日表缺失 | ✅ 可接受 | 表到 2027 为止符合国办发布节奏（2027 通知 2026-11 发布、2028 通知 2027-11 发布）；ITER-14 待办区 + maintenance-notes 已登记每年 11 月核对流程 |

### 二、下一轮建议（ITER-16+，按优先级）

- **ITER-16 【低】金丝雀锚点按年度滚动**
  现状：金丝雀当前只覆盖 2026。2026-11 核对 2027 官方通知并更新 2027 预估段时
  （ITER-14 待办），应同步为 2027 段补充官方锚点（各节日窗口端点 + 全部官方补班日）。
  风险：无（纯测试文件）；维护说明已写入 maintenance-notes 步骤 3。

- **ITER-17 【低】file-structure.zh.md 单测计数停止写死**
  现状：计数已三度漂移（16→56→57→59），每轮 review 都要修一次。建议改为不写具体
  数字（「数量以 `make test` 输出为准」），或加 CI grep 校验防漂移。风险：无。

- **ITER-18 【低】publish.yml 自检逻辑加 CI 冒烟**
  现状：ITER-13 的 KEY_LEN guard 只在 v* tag 发布时执行，日常 PR CI（build-test.yml）
  不覆盖——workflow 未来若被改坏要等发版才暴露。建议在 build-test.yml 加一个纯 shell
  冒烟步骤（伪造 base64 数据跑同款 guard 逻辑，断言正常/错误两分支 exit code）。
  风险：无。

### 三、实施批次建议

- **Batch 1（1 张卡，可选）**：ITER-16（金丝雀滚动，建议 2026-11 随 ITER-14 待办一起做）；
- **Batch 2（1 张卡，可选）**：ITER-17 + ITER-18（文档计数去硬编码 + CI 冒烟，各 <15 行）。

---

## 七、第五轮审查（ITER-16~18 全部合并后，由 review-agent t_e7950587 产出）

> 在 ITER-16~18（PR #34~#36，squash 合并 13db6ee/508f346/adbec30）+ INTEG docs commit 6a8e468
> 全部并入 main 之后，通读合并 diff（2253dff..6a8e468，7 文件、+187/-24），审查方向：
> ITER-16 2027 锚点与预估表一致性、ITER-18 共享脚本 / publish.yml 引用正确性、
> 新 workflow（signing-check.yml）触发条件、代码一致性、文档遗留。

### 〇、本轮 review 直接修复（PR #37，CI 全绿后合入）

- **ITER-16 金丝雀周末锚点掩蔽缺口（2 处）**：`testGoldenAnchors2027`
  （`LyricsMTMR/MTMRTests/StockMarketHoursTests.swift:180-189`）的春节 2027-02-06(六) 与
  劳动节 2027-05-01(六) 落在周末——即使被误删出 `aShareHolidays`，`isMarketOpen` 的周末规则
  也会兜底返回休市，锚点断言依然通过，与金丝雀注释声称的「表若被误改，锚点立即失败」
  （:147-148）相悖。已补 `aShareHolidays.contains(...)` 直查断言（:190-196）+ 注释说明，
  并在测试区块年度滚动步骤（:146-147）与 maintenance-notes 步骤 3 登记「周末节日锚点须直查」
  要求（2026 锚点均为工作日或补班开市断言，无此问题；后续年度如 2028 元旦周六会再遇）。
- **file-structure.zh.md 未收录 ITER-18 新增文件**：`.github/scripts/verify_sparkle_key.sh`
  与 `.github/workflows/signing-check.yml`（ITER-18 新增）未登记在 CI mindmap
  （`LyricsMTMR/docs/file-structure.zh.md:46-51`），文档与目录结构漂移。已补两行。
- **iteration-plan 本轮追记**：本区块（修复项 / 排除清单 / 下一轮建议落盘）。

### 一、已排除候选清单（本轮确认无问题，避免重复改）

| 项 | 结论 | 证据 |
|---|---|---|
| ITER-16 2027 锚点与预估表一致性 | ✅ | 7 个锚点日期全部存在于 `aShareHolidays`（`StockBarItem.swift:388-398`），且均不在 `aShareMakeupDates`（:412-418，两表重叠另有 `testHolidayAndMakeupTablesDisjoint` 守卫）；Python 复核 7 个星期标注（五/六/一/六/三/三/五）与断言消息逐一吻合；农历日期（春节 02-06 正月初一、端午 06-09、中秋 09-15）为天文历确定值，除夕 02-05 腊月二十九亦与表注释一致 |
| ITER-16 2026 金丝雀改名后无遗留引用 | ✅ | grep 全仓无 `CanaryOfficial` / `testCanary*` 残留；maintenance-notes.md:35-37 已同步新名 testGoldenAnchors* |
| ITER-18 共享脚本与 ITER-13 内联 guard 等价 | ✅ | `.github/scripts/verify_sparkle_key.sh:20-27` 与 2253dff 版 publish.yml:63-67 逐行一致（含错误文案）；macOS 本地 8 类输入实测全部符合预期：base64(96B)→0、PEM 文本→1、base64(64B)→1、空文件→1、文件不存在→1、96B+尾随空白→0、base64(128B)→1、真实 PEM 块→1 |
| ITER-18 publish.yml 脚本引用路径 | ✅ | 「Generate appcast.xml」步骤无 `working-directory` 覆盖，checkout@v4（publish.yml:14）后默认 $GITHUB_WORKSPACE 根目录，相对路径 `.github/scripts/verify_sparkle_key.sh` 可解析；脚本 exit 1 → GitHub 默认 `bash -e` 使步骤失败，fail-closed 语义与内联 guard 一致（内联原为 set -e+pipefail 下命令替换失败即退，殊途同归） |
| ITER-18 signing-check.yml 触发条件与断言 | ✅ | `on: pull_request` + `workflow_dispatch`（signing-check.yml:12-15）：PR 期即冒烟，无需等 v* tag 发版；三输入断言在 `set -euo pipefail` 下用 `if` 条件豁免正确；mktemp 用完即删、断言计数门禁齐全（:59-64） |
| ITER-17 去硬编码后残留数字 | ✅ | file-structure.zh.md 残留数字逐一核对：`v* tag`（:51 workflow 触发条件）、`theme1-15`（:53 预设命名）、`MTMRTryOrError 3 处`（:135 = 3 个 Swift 文件，grep 实证 TouchBarController / WidgetKit / AudioSpectrumBarItem）、`x86_64 + arm64`（:149 架构）、`3 个 commit` + 哈希（:155-161 历史记录），均非会漂移的计数 |
| 2028 节假日表缺失 | ✅ 可接受 | 同第四轮结论：符合国办发布节奏（2028 通知 2027-11 发布）；ITER-14 置顶待办 + maintenance-notes 已登记每年 11 月核对流程 |

### 二、下一轮建议（ITER-19+，按优先级）

- **ITER-19 【低】金丝雀周末锚点直查化（后续年度自动生效）**
  现状：本轮已修 2027 两处周末锚点（contains 直查）；维护说明与测试区块注释已登记该要求。
  2028 元旦（周六）等周末节日落表时按注释执行即可。风险：无（纯测试 + 文档，已随本轮合入）。

- **ITER-20 【低】signing-check.yml 触发面收敛**
  现状：`on: pull_request` 对全部 PR 生效（含 draft / 纯文档 PR）。可选 `paths:` 过滤
  （`.github/scripts/**`、`.github/workflows/publish.yml`、`.github/workflows/signing-check.yml`）。
  收益小（冒烟 <10s）；paths 方案需同时列出 publish.yml 路径，否则改 publish.yml 不会触发冒烟。
  风险：低（过滤误配会漏跑冒烟，需在 PR 描述注明）。

- **ITER-21 【低】2027 预估段复核时点提醒**
  现状：ITER-14 置顶待办已覆盖（2026-11 国办通知后核对连休窗口/补班日），无需新卡；
  届时按 maintenance-notes 步骤 3 同步补连休端点金丝雀锚点（若官方窗口与预估一致则仅去「预估」标注）。
  风险：无（流程已固化）。

### 三、实施批次建议

- 本轮修复（金丝雀直查 + CI 文件结构补录 + 文档追记）已在单个 PR（#37）内完成，无需拆分；
  ITER-19~21 均为低优先可选卡，建议 2026-11 随 ITER-14 核对待办一起评估。

---

## 八、第六轮审查（ITER-20 合并后，由 review-agent t_a314745d 产出）

> 在 ITER-20（PR #38，squash 合并 e5f52d7）+ INTEG docs commit 9cf68a5 并入 main 之后，
> 通读合并 diff（a6ed575..9cf68a5，2 commits、2 文件、+36/-1），审查方向：
> signing-check.yml paths 过滤正确性（改 publish.yml 是否仍触发冒烟 / 纯文档 PR 是否确实不触发 /
> workflow_dispatch 是否不受限）、代码一致性、文档遗留；并对优化空间做收敛评估。

### 〇、本轮 review 直接修复（文档一致性，随本轮 docs PR 合入）

- **file-structure.zh.md:54 注释未随 ITER-20 收敛**：CI mindmap 中 signing-check.yml 注释仍写
  「PR：Sparkle 私钥格式 guard 冒烟（ITER-18）」，暗示所有 PR 都跑；ITER-20 后实际触发面为
  「PR（仅 paths 命中）+ 手动触发」。已改为与 signing-check.yml:7-8 注释一致的表述
  （与前几轮同类文档漂移，无逻辑改动）。

### 一、已排除候选清单（本轮确认无问题，避免重复改）

| 项 | 结论 | 证据 |
|---|---|---|
| paths 三路清单完备性 | ✅ | verify_sparkle_key.sh 为独立 bash（仅依赖系统 base64/wc，`verify_sparkle_key.sh:14-29`），仓库内无其他文件影响其行为；publish.yml 是唯一消费方（`publish.yml:65` 调用）；build-test.yml 不涉及签名逻辑。signing-check.yml:14-16 三路（`.github/scripts/**` / `publish.yml` / workflow 自身）即触发面全集，无漏列 |
| 纯文档 PR 不触发 | ✅ | paths 仅限上述三路；docs/、LyricsMTMR/ 下源文件改动均不命中 → 冒烟不跑，与收敛目标一致（GitHub paths 语义：pull_request 按变更文件评估）；本轮 docs PR 即为实证（见 PR #39 checks） |
| workflow_dispatch 不受限 | ✅ | paths 过滤器只作用于 pull_request 分支（signing-check.yml:12-17），manual trigger 恒可跑，与注释「手动，不受 paths 限制」（:7）一致 |
| 改 publish.yml 仍触发冒烟 | ✅ | `.github/workflows/publish.yml` 在 paths 清单内（:15）；未来 publish.yml 改脚本调用方式（参数/工作目录）时变更即命中该路径 → 冒烟覆盖 |
| 冒烟自触发语义生效 | ✅ 实证 | PR #38 三 checks 全绿：build/test（1m12s）+ smoke（5s），smoke 由 PR 自身改动触发 → 「本 workflow 改动必须能触发自身」（signing-check.yml:8）防漏列语义生效 |
| glob 语法正确性 | ✅ | `.github/scripts/**` 的 `**` 匹配任意层级（含直接子文件 verify_sparkle_key.sh），与 GitHub 官方 `sub-project/**` 示例语义一致 |
| 冒烟三输入分支完备 | ✅ | verify_sparkle_key.sh 仅一条判别路径：`base64 -d` 后长度≠96B → exit 1（:25-29）；输入 2（PEM 文本）覆盖「解码失败→0B→≠96B」、输入 3（64B）覆盖「解码成功但长度≠96B」（signing-check.yml:44-66），两错误分支均被覆盖；第五轮本地 8 类输入实测（含真实 PEM 块、128B、空文件）已证等价，无新增输入价值 |
| 冒烟不跑在 push/main | ✅ 设计如此 | 项目协议所有改动走 PR（合并史无直接 main 提交）；PR 期冒烟已覆盖变更；build-test.yml 对 main push 全量重跑（build-test.yml:4-5），签名冒烟无需重复 |
| signing-check.yml 注释与 on 块一致 | ✅ | 头部注释（:7-8）与 on 块（:12-17）描述逐字对应；optimization-plan.md 第六轮块（:52-58）与实施记录一致 |
| ITER-15 AppScrubber 事件驱动 | ✅ 维持可选项 | 与第五轮结论一致：需镜像窗实际使用场景确认后再做，不阻塞收敛 |

### 二、收敛评估与后续维护路径（ITER-21 后不再开实现卡）

**收敛结论**：自 OPT 19 项以来的优化/修复空间已收敛。证据：
1. 各轮合并 diff 规模持续收窄：+538/-100（OPT）→ +583/-61（ITER-1~6）→ +150/-49（ITER-7~11）
   → +336（ITER-12~14）→ +187/-24（ITER-16~18）→ **+6/-1**（ITER-20，单文件）；
2. ITER-1~21 建议清单全部实现或明确排期/排除，无遗留未处理项；
3. 本轮全量通读未发现功能回归，唯一不一致为文档注释漂移（已修）。

**剩余未结项仅两类，均非代码实现卡**：
- 时间驱动：ITER-14/21（2026-11 国办发布 2027 节假日通知后核对 `StockBarItem.swift` 2027 预估段，
  置顶待办 + maintenance-notes.md:22-47 年度流程已固化）；
- 可选观察：ITER-15（镜像窗快照事件驱动刷新，需使用场景确认后再评估）。

**后续维护路径**（无需新卡，按既有流程执行）：
1. 每年 11 月国办通知后按 maintenance-notes.md 步骤 1-3 核对节假日表 + 滚动补充金丝雀锚点
   （含周末锚点直查规则，maintenance-notes.md:39-40）；
2. 若未来新增消费 verify_sparkle_key.sh 的 workflow，须同步加入 signing-check.yml paths 清单
   （signing-check.yml:8 注释已登记该要求）；
3. 密钥轮换时 SPARKLE_PRIVATE_KEY 与 Info.plist SUPublicEDKey 同源由 publish.yml 交叉自检兜底
   （publish.yml:90-97），无需人工步骤。
