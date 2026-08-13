# LyricsMTMR 维护说明（Maintenance Notes）

> 汇总仓库内需要「定期人工跟进」的维护项，避免时间敏感事项被遗忘。
> 置顶待办见 `docs/iteration-plan.md` 顶部「待办区」。

## 1. A 股节假日表（aShareHolidays / aShareMakeupDates）

### 数据源与上交流程

- **唯一权威源**：国务院办公厅《关于 YYYY 年部分节假日安排的通知》（国办发明电〔YYYY〕N 号），
  每年约 **11 月**发布次年通知，发布于 gov.cn 政策库。
- **URL 模式**：`https://www.gov.cn/zhengce/zhengceku/YYYYMM/content_XXXXXXX.htm`
  - 例：2026 年安排 = 国办发明电〔2025〕7 号（2025-11-04 发布）：
    `https://www.gov.cn/zhengce/zhengceku/202511/content_7047091.htm`
- **上交流程**：以官方通知原文逐日核对 → 在代码注释中记录文号 + URL
  （参见 `StockBarItem.swift:374-375` 的 2026 写法）→ 提交 PR 合入 main。
- **代码位置**：`LyricsMTMR/MTMR/Widgets/Life/StockBarItem.swift`
  - `aShareHolidays`（休市日，含假期窗口内周末，便于整窗核对）：`:380-404`
  - `aShareMakeupDates`（调休补班日，周末上班视为交易日）：`:409-424`
  - 两表是 `isMarketOpen` 与 MTMRTests 的**唯一数据源**（ITER-7 / ITER-8），**必须一起维护**。

### 每年更新步骤（国办 11 月发布通知后）

1. **核对**：取官方通知原文，逐日比对两表中对应年份段与通知的放假 / 补班安排。
   当前 2027 段为预估（春节 / 端午 / 中秋节日当天为农历天文历确定值，**连休窗口与补班日为预估**），
   重点检查点：
   - 春节连休窗口与补班日（当前预估 2/5(五)除夕 ~ 2/12(五)初七，共 8 天，补班 1/30、2/13）；
   - 端午连休窗口与补班日（当前预估 6/7(一) ~ 6/9(三)，补班 6/5）；
   - 中秋连休窗口与补班日（当前预估 9/13(一) ~ 9/15(三)，补班 9/11）；
   - 其余节日窗口（元旦 / 清明 / 劳动 / 国庆）是否与官方通知一致。
2. **改表**：更新 `aShareHolidays` / `aShareMakeupDates` 对应年份段，并同步更新段注释
   （去掉「预估」标注、补上文号 + URL）。
3. **更新测试锚点**：`LyricsMTMR/MTMRTests/StockMarketHoursTests.swift` 为 ITER-8 表驱动断言，
   直接从两表生成断言——**改表后跑测试即自动覆盖**；另有按年度分组的「官方锚点金丝雀」
   （ITER-12 / ITER-16，固定日期断言，见 `StockMarketHoursTests.swift` 金丝雀区段
   `testGoldenAnchors2026` / `testGoldenAnchorsMakeup2026` / `testGoldenAnchors2027`）
   独立于两表——新年份核对落表后，应同步在该年度块补充官方锚点
   （至少各节日窗口端点 + 全部官方补班日；连休/补班未确定前只补节日当天锚点；
   落在周末的节日锚点须加表内 `contains` 直查断言，防周末规则掩蔽——如 2027 春节 02-06、
   劳动 05-01，见 `testGoldenAnchors2027` 注释）。
4. **验证**：跑 `MTMRTests` 全量通过后提交 PR（改动应为纯数据 + 注释）。

### 修订历史

- 2026 年：官方（国办发明电〔2025〕7 号）—— ITER-4 首次引入，ITER-7 外置为唯一数据源。
- 2027 年：节日当天为农历/公历确定值（已补金丝雀 `testGoldenAnchors2027`）；连休窗口与补班仍为预估
  —— 待 2026-11 国办通知核对（置顶待办 ITER-14，见 `docs/iteration-plan.md`）。

## 2. Sparkle 更新签名密钥

- **保管位置**：`~/Documents/LyricsMTMR-Sparkle`（本机目录，**永不入库**）。
- 仓库内只保留公钥：`Info.plist` 的 `SUPublicEDKey`；appcast.xml 的 `sparkle:edSignature`
  由 publish.yml 用 GitHub Secret（`SPARKLE_PRIVATE_KEY`）在 CI 生成（ITER-1 / ITER-10）。
- **纪律**：私钥文件永不提交；密钥轮换时须同步更新 `SUPublicEDKey` 与 GitHub Secret——
  二者不同源会出现「CI 绿但客户端验签失败」（ITER-10 已加 CI 交叉自检兜底）。

## 3. 其他周期性事项

（暂无 —— 新增时间敏感事项时，同步在 `docs/iteration-plan.md` 待办区登记。）
