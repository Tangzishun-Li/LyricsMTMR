# LyricsMTMR JSON 可视化编辑器 — 全量 Widget 参数参考

> **生成日期**：2026-09-14
> **数据来源**：EditorSchema.swift（编辑器注册表）、ItemsParsing.swift（JSON 解码+默认值）、BarItemFactory.swift（工厂 switch）、94 个 Widget 实现文件逐个交叉验证（全部已读）
> **覆盖范围**：17 个分类，99 个注册类型，约 250+ 独立可配置属性
> **验证状态**：全部 94 个 .swift widget 文件已逐个比对 init 参数与 ItemType 枚举，无遗漏

---

## 目录

1. [通用属性（所有 Widget 共享）](#一通用属性)
2. [PropType — 编辑器控件类型](#二proptype--编辑器控件类型)
3. [分组系统（Section）](#三分组系统)
4. [全量 Widget 分类详解](#四全量-widget-分类详解)
   - [基础 Basic](#41-基础-basic)
   - [媒体 Media](#42-媒体-media)
   - [系统 System](#43-系统-system)
   - [信息 Info](#44-信息-info)
   - [增强 Extra](#45-增强-extra)
   - [音乐增强 Music+](#46-音乐增强-music)
   - [特殊 Misc](#47-特殊-misc)
   - [开发者 Dev](#48-开发者-dev)
   - [极客 Geek](#49-极客-geek)
   - [工具箱 Tools](#410-工具箱-tools)
   - [生活 Life](#411-生活-life)
   - [健康 Health](#412-健康-health)
   - [办公 Office](#413-办公-office)
   - [校园 Campus](#414-校园-campus)
   - [财务 Finance](#415-财务-finance)
   - [运维 Ops](#416-运维-ops)
   - [系统+ System+](#417-系统-system-1)
   - [创意 Creative](#418-创意-creative)
5. [编辑器未暴露但 JSON 可用的类型](#五编辑器未暴露但-json-可用的类型)
6. [内置快捷类型](#六内置快捷类型)
7. [Action 系统（点击/长按动作）](#七action-系统)

---

## 一、通用属性

所有 widget 在 JSON 层面都可附加以下通用字段（由 `GeneralParameters` 解码）。编辑器中部分以「高级」分组展示。

| 字段 | JSON 类型 | Swift 类型 | 说明 | 默认值 | 必填 | 备注 |
|------|----------|-----------|------|--------|------|------|
| `width` | number | CGFloat | 按钮宽度（pt） | 64 | 否 | 0 = 自动宽度 |
| `align` | string | Align | Touch Bar 内对齐 | `"center"` | 否 | `"left"` / `"center"` / `"right"` |
| `bordered` | bool | Bool | 是否显示按钮边框 | true | 否 | |
| `background` | string | NSColor | 背景色 | 无 | 否 | hex 格式如 `"#FF5722"` |
| `title` | string | String | 覆盖显示标题 | 无 | 否 | 会覆盖 widget 自身的标题 |
| `image` | object | Source | 按钮图标 | 无 | 否 | 见 Source 结构说明 |
| `matchAppId` | string | String | 匹配 app bundle ID | 无 | 否 | 前台 app 匹配时自动显示/隐藏 |
| `divider` | bool | Bool | 是否显示分隔线 | 无 | 否 | 仅在 expandable 子项中有效 |

### Source 结构（图片/脚本源）

图片和脚本类字段都用 Source 结构：

```json
{ "filePath": "~/icon.png" }
{ "base64": "iVBORw0KGgo..." }
{ "inline": "tell application \"Finder\"..." }
```

三种方式任选其一。filePath 支持 `~` 展开。

---

## 二、PropType — 编辑器控件类型

编辑器 Inspector 根据 `PropType` 枚举渲染不同控件：

| PropType | 控件 | 接受值 | 说明 |
|----------|------|--------|------|
| `text(placeholder)` | 文本输入框 | String | placeholder 为提示文字 |
| `integer(placeholder)` | 数字输入框 | Int/Double | placeholder 为示例数字 |
| `boolean` | 开关 toggle | true/false | 布尔开关 |
| `selection([String])` | 下拉选择器 | 选项列表中的一个 | 只能选预定义值 |
| `stringList(placeholder)` | 标签列表 | String 数组 | 逐项添加，每项一个标签 |
| `slider(range, step, unit)` | 滑动条 | Double | 有范围、步长、单位 |
| `filePicker(allowedTypes)` | 文件选择器 | 文件路径 | 可限制文件类型 |
| `colorPicker` | 颜色选择器 | hex String | 默认 `"#FFFFFF"` |

---

## 三、分组系统

编辑器自动将属性分为以下区域（按优先级排列）：

| 分组名 | 包含的 key | 说明 |
|--------|-----------|------|
| **基本 (General)** | title 等未归类字段 | 默认分组 |
| **动作 (Action)** | `action`, `actionAppleScript` | 点击/长按行为 |
| **显示 (Display)** | `width`, `align`, `bordered`, `showChart`, `barCount`, `karaokeStyle`, `displayMode` | 外观相关 |
| **数据源 (Data)** | `refreshInterval`, `dataPath`, `configPath`, `filePath`, `repoPath`, `endpoint`, `host`, `repo`, `provider`, `stocks`, `channels`, `scenes`, `trackingNumber`, `company`, `calendarFilter`, `lat`, `lon`, `annualIncome`, `defaultUrl`, `defaultPort`, `prompt`, `model`, `formatTemplate` | 数据输入/刷新 |
| **API** | `apiUrl`, `apiMethod`, `apiJqPath` | HTTP API 配置 |
| **高级 (Advanced)** | 其他 | |

---

## 四、全量 Widget 分类详解

### 图例

- **必填**：省略则 JSON 解码失败，widget 降级为 `unknown`
- **可选**：省略则使用默认值
- **仅 JSON**：编辑器不暴露，需手写 JSON
- **slider**：格式为 `slider(最小值...最大值, 步长, 单位)`
- **selection**：格式为 `selection([选项1, 选项2, ...])`

---

### 4.1 基础 (Basic)

#### `staticButton` — 自定义按钮

自定义按钮，点击可执行 AppleScript 或打开应用。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 分组 | 说明 |
|------|------|--------|--------|------|------|------|
| `title` | text | 任意字符串 | `"Button"` | **是** | 基本 | 按钮显示文字 |
| `width` | integer | 正整数（pt） | 64 | 否 | 基本 | 按钮宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 基本 | 对齐方式 |
| `bordered` | boolean | true/false | true | 否 | 基本 | 是否显示边框 |
| `action` | selection | `"none"` / `"appleScript"` / `"shellScriptPath"` / `"openUrl"` | `"none"` | 否 | 动作 | 点击动作类型 |
| `actionAppleScript` | text | AppleScript 代码 | — | 否 | 动作 | 内联 AppleScript（依赖 action=appleScript） |
| `apiUrl` | text | HTTP/HTTPS URL | — | 否 | API | 动态内容 API 端点 |
| `apiMethod` | selection | `"GET"` / `"POST"` / `"PUT"` | `"GET"` | 否 | API | HTTP 请求方法 |
| `apiJqPath` | text | jq 表达式 | — | 否 | API | 从 JSON 响应提取显示字段，如 `.data.value` |

#### `escape` — Esc 键

模拟键盘 Esc 键。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `width` | integer | 正整数（pt） | 64 | 否 | 按钮宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `timeButton` — 时钟

显示当前时间，支持自定义格式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 分组 | 说明 |
|------|------|--------|--------|------|------|------|
| `formatTemplate` | text | DateFormatter 格式字符串 | `"HH:mm"` | 否 | 基本 | 时间格式，如 `"yyyy-MM-dd HH:mm"` / `"EEE HH:mm"` / `"h:mm a"` |
| `width` | integer | 正整数（pt） | 80 | 否 | 基本 | 按钮宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 基本 | 对齐 |
| `timeZone` | text | IANA 时区标识 | nil | 否 | 仅JSON | 如 `"Asia/Shanghai"` / `"America/New_York"` / `"Europe/London"` |
| `locale` | text | Locale 标识 | nil | 否 | 仅JSON | 如 `"zh_CN"` / `"en_US"`，影响星期/月份名称 |

**formatTemplate 常用格式**：
- `HH:mm` — 24小时制，如 `14:30`
- `h:mm a` — 12小时制，如 `2:30 PM`
- `HH:mm:ss` — 含秒
- `yyyy-MM-dd HH:mm` — 含日期
- `EEE HH:mm` — 含星期
- `MM/dd HH:mm` — 月/日 + 时间

#### `battery` — 电池

显示电池电量和充电状态，自动更新。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `cpu` — CPU 使用率

实时 CPU 使用率，自动更新。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `refreshInterval` | number | 秒（正数） | 5.0 | 否 | 仅JSON，刷新间隔 |

#### `volume` — 音量滑块

系统音量滑块控件。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `brightness` — 亮度滑块

屏幕亮度滑块控件。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `bordered` | boolean | true/false | — | 否 | 边框 |
| `refreshInterval` | number | 秒 | 0.5 | 否 | 仅JSON，刷新间隔 |

---

### 4.2 媒体 (Media)

#### `music` — 当前播放

显示当前播放歌曲信息（支持 Apple Music / Spotify / VOX / Chrome / Safari）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `refreshInterval` | number | 秒 | 5.0 | 否 | 仅JSON，轮询间隔 |
| `disableMarquee` | boolean | true/false | false | 否 | 仅JSON，禁用跑马灯滚动 |

**交互**：单击=播放/暂停，双击=上一首，长按=下一首。

#### `play` — 播放/暂停

播放/暂停按钮（发送系统媒体键）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `bordered` | boolean | true/false | — | 否 | 边框 |

#### `next` — 下一首

下一首按钮（发送系统媒体键）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `bordered` | boolean | true/false | — | 否 | 边框 |

#### `previous` — 上一首

上一首按钮（发送系统媒体键）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `bordered` | boolean | true/false | — | 否 | 边框 |

---

### 4.3 系统 (System)

#### `dock` — Dock 应用

在 Touch Bar 中显示 Dock 应用图标，支持正则过滤。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `width` | integer | 正整数（pt） | 200 | 否 | 容器宽度 |
| `autoResize` | boolean | true/false | false | 否 | 仅JSON，根据图标数量自动调整宽度 |
| `filter` | text | 正则表达式 | nil | 否 | 仅JSON，按应用名过滤（如 `"Safari\|Chrome"`） |
| `showRunning` | boolean | true/false | true | 否 | 仅JSON，是否显示运行中的应用 |
| `maxApps` | integer | 0=不限 | 0 | 否 | 仅JSON，最大显示数量 |
| `iconSize` | number | pt | 32 | 否 | 仅JSON，图标大小 |
| `apps` | string[] | app bundle ID 列表 | [] | 否 | 仅JSON，固定显示的应用（覆盖全局设置） |

**交互**：单击=切换到应用，长按=从 Dock 移除固定。

#### `darkMode` — 深色模式

切换系统深色模式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `dnd` — 勿扰模式

切换勿扰模式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |
| `width` | integer | pt | 38 | 否 |

#### `nightShift` — 夜览

切换夜览模式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `inputsource` — 输入法

显示/切换当前输入法。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `pomodoro` — 番茄钟

番茄钟计时器，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `workTime` | number | 秒 | 1500.0 (25分钟) | 否 | 仅JSON，工作时长 |
| `restTime` | number | 秒 | 600.0 (10分钟) | 否 | 仅JSON，休息时长 |

---

### 4.4 信息 (Info)

#### `weather` — 天气

显示当前天气和温度，支持 OpenWeatherMap 和中国天气网双数据源。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 分组 | 说明 |
|------|------|--------|--------|------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 显示 | 对齐 |
| `refreshInterval` | number | 秒 | 1800.0 (30分钟) | 否 | 数据源 | 刷新频率 |
| `units` | selection | `"metric"` / `"imperial"` | `"metric"` | 否 | 数据源 | 温度单位 |
| `api_key` | text | OpenWeatherMap API key | `""` | 否 | API | openweather 模式必填 |
| `icon_type` | selection | `"text"` / `"images"` | `"text"` | 否 | 显示 | 图标类型 |
| `apiSource` | selection | `"openweather"` / `"china"` | `"openweather"` | 否 | 数据源 | china=中国天气网(无需key) |
| `cities` | string[] | 城市代码列表 | [] | 否 | 数据源 | china 模式下多城市，点按切换 |
| `showHumidity` | boolean | true/false | false | 否 | 显示 | 显示湿度 |
| `showWind` | boolean | true/false | false | 否 | 显示 | 显示风力 |

**中国天气网城市代码**：见 `ChinaCityCodes.json`，如 `"101010100"` = 北京。

#### `currency` — 汇率

实时汇率转换。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `refreshInterval` | number | 秒 | 600.0 (10分钟) | 否 | 刷新频率 |
| `from` | text | 货币代码 | `"RUB"` | 否 | 源货币 |
| `to` | text | 货币代码 | `"USD"` | 否 | 目标货币 |
| `full` | boolean | true/false | false | 否 | true=显示完整汇率信息 |

**支持的货币代码**：USD, EUR, RUB, JPY, GBP, CAD, KRW, CNY, AUD, BRL, IDR, MXN, SGD, CHF, BTC, LTC, ETH, SOL, DOT, DOGE, XMR, ADA, PLN, UAH, USDT

**货币符号映射**：`$` `€` `₽` `¥` `₤` `₩` `R$` `Rp` `฿` `Ł` `Ξ` `◎` `●` `Ð` `ɱ` `₳` `zł` `₴`

#### `stock` — 股票

**最复杂的 widget 之一**。显示股票/基金实时行情，支持迷你走势图和跑马灯模式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 分组 | 说明 |
|------|------|--------|--------|------|------|------|
| `stocks` | string[] | 股票代码 | `["sh600519"]` | 否 | 数据源 | 要监控的股票代码列表 |
| `apiSource` | selection | `"tencent"` / `"eastmoney"` | `"tencent"` | 否 | 数据源 | 腾讯/东方财富数据源 |
| `displayMode` | selection | `"compact"` / `"expanded"` / `"marquee"` | `"compact"` | 否 | 基本 | compact=仅价格, expanded=含涨跌幅, marquee=跑马灯轮播 |
| `showChart` | boolean | true/false | true | 否 | 显示 | 迷你走势折线图 |
| `chartWidth` | slider | 30~120 pt, step 5 | 130 | 否 | 显示 | 图表宽度（依赖 showChart） |
| `chartMode` | text | `"fenzhong"` | `"fenzhong"` | 否 | 显示 | 仅JSON，图表模式（分钟线） |
| `refreshInterval` | slider | 5~300 秒, step 5 | 10 | 否 | 数据源 | 行情刷新频率，休市时自动降频到 60s |
| `textWidth` | number | pt | 70 | 否 | 仅JSON | 文字区宽度 |
| `width` | integer | pt | 200 | 否 | 显示 | 总宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 显示 | 对齐 |

**股票代码格式**：

| 市场 | 腾讯源格式 | 东方财富源格式 | 示例 |
|------|-----------|---------------|------|
| A 股（上证） | `sh` + 6位代码 | `SH` + 6位代码 | `sh600519` / `SH600519` |
| A 股（深证） | `sz` + 6位代码 | `SZ` + 6位代码 | `sz000001` / `SZ000001` |
| 板块 | — | `BK` + 代码 | `BK0477` |
| 港股 | `0700.HK` | — | `0700.HK` |
| 美股 | `AAPL` | — | `AAPL` |

**A 股交易时段（内置判断）**：
- 早盘：9:15 ~ 11:30（北京时间）
- 午盘：13:00 ~ 15:00
- 法定节假日自动休市（2026~2027 国务院安排已内置）
- 调休补班日视为交易日
- 休市时刷新频率自动降至 >= 60s

**交互**：marquee 模式下单击切换下一只股票。

#### `upnext` — 日历日程

显示下一个日历事件。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `from` | number | 小时 | 0 | 否 | 仅JSON，搜索起始时间（从现在起 N 小时） |
| `to` | number | 小时 | 12 | 否 | 仅JSON，搜索截止时间 |
| `maxToShow` | integer | 1~N | 3 | 否 | 仅JSON，最多显示几个事件 |
| `autoResize` | boolean | true/false | false | 否 | 仅JSON，自动调整宽度 |

---

### 4.5 增强 (Extra)

#### `lyrics` — 歌词

显示当前播放歌词，支持卡拉OK模式。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 分组 | 说明 |
|------|------|--------|--------|------|------|------|
| `width` | integer | pt | 350 | 否 | 显示 | 歌词区宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 显示 | 对齐 |
| `displayMode` | selection | `"karaoke"` / `"static"` / `"artwork"` | `"karaoke"` | 否 | 显示 | 卡拉OK/静态/封面 |
| `karaokeStyle` | selection | `"progressive"` / `"jump"` | `"progressive"` | 否 | 显示 | 渐进式/跳跃式 |
| `showArtwork` | boolean | true/false | true | 否 | 仅JSON | 显示专辑封面 |
| `clickAction` | text | `"original"` 等 | `"original"` | 否 | 仅JSON | 点击动作 |
| `marqueeEnabled` | boolean | true/false | true | 否 | 仅JSON | 启用跑马灯 |
| `marqueeStyle` | text | `"marquee"` 等 | `"marquee"` | 否 | 仅JSON | 跑马灯风格 |

#### `themeSwitch` — 主题切换

快速切换 Touch Bar 主题，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `themes` | ThemeDefinition[] | 主题定义数组 | [] | 否 | 仅JSON，预配置主题列表 |

**ThemeDefinition 结构**：
```json
{
  "label": "主题名",
  "preset": "theme1.json",
  "matchAppIds": ["com.apple.Safari"]
}
```
- `label`：显示名（可选，null 时用 preset 文件名）
- `preset`：主题文件名（相对于 Application Support/LyricsMTMR/）
- `matchAppIds`：前台 app 匹配时自动切换（可选）

**行为**：即使 themes 为空，也会自动发现磁盘上所有 theme*.json 文件。

#### `deepseekBalance` — DeepSeek 余额

显示 DeepSeek API 余额。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `apiKey` | text | DeepSeek API key | `""` | 否 | 仅JSON，为空时用设置里的 |
| `displayMode` | text | `"both"` 等 | `"both"` | 否 | 仅JSON |
| `showRemaining` | boolean | true/false | true | 否 | 仅JSON |
| `refreshInterval` | number | 秒 | 3600 | 否 | 仅JSON |

#### `opencodeGoUsage` — OpenCode Go 用量

显示 OpenCode Go 订阅用量（5小时/周/月限额），有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `displayMode` | selection | `"worst"` / `"rolling"` / `"weekly"` / `"monthly"` / `"all"` | `"worst"` | 否 | 显示哪个时间窗口 |
| `refreshInterval` | integer | 秒，最小 60 | 300 | 否 | 刷新频率 |
| `workspaceID` | text | Workspace ID | `""` | 否 | 留空自动发现 |
| `cookie` | text | 浏览器 cookie | `""` | 否 | 留空用设置里的 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

**displayMode 说明**：
- `worst` — 显示最接近限额的时间窗口（默认，最醒目）
- `rolling` — 5小时滚动窗口
- `weekly` — 本周用量
- `monthly` — 本月用量
- `all` — 显示所有窗口

---

### 4.6 音乐增强 (Music+)

#### `audioSpectrum` — 音频频谱

实时音频频谱可视化。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `barCount` | integer | 8~48 | 自动(宽度/8) | 否 | 频谱柱数 |
| `width` | integer | pt | 120 | 否 | 总宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `source` | selection | `"system"` / `"mic"` / `"auto"` | `""` | 否 | 仅JSON，音频源 |

**barCount 自动计算**：未指定时 = `width / 8`（范围 8~48），默认宽度 120pt → 16 柱。

**音频源说明**：
- `system` — 捕获系统播放音频（需 Screen Recording 权限，macOS 13+）
- `mic` — 麦克风环境音（需 Microphone 权限）
- `auto` — 尝试系统源，不可用时用合成器（跟随歌词引擎播放状态）

**额外设置**（在「设置 → 工具 → 音量律动」中，非 JSON）：
- 低/中/高频增益 (0~2)
- 低/中/高频释放 (0.05~0.95)

#### `playbackProgress` — 播放进度条

显示当前歌曲播放进度。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 200 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `lyricsTranslate` — 歌词翻译

歌词翻译切换按钮。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 44 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `quickReply` — 快捷回复

快捷回复预设消息，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `configPath` | text | 文件路径 | nil | 否 | 配置文件路径（留空用默认） |
| `width` | integer | pt | 44 | 否 | 按钮宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

---

### 4.7 特殊 (Misc)

#### `group` — 分组

将多个元素折叠为一个按钮，点击展开，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `title` | text | 任意 | `"Group"` | 否 | 分组名称 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `items` | BarItemDefinition[] | 子项数组 | — | **是(仅JSON)** | 嵌套的 widget 定义 |

#### `swipe` — 滑动手势

左右滑动切换多页内容，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `direction` | text | **必填** | — | **是** | 滑动方向：`"left"` / `"right"` / `"up"` / `"down"` |
| `fingers` | integer | **必填** | — | **是** | 手指数（1~N） |
| `minOffset` | float | 最小滑动距离 | 0.0 | 否 | 触发阈值 |
| `sourceApple` | Source | AppleScript | nil | 否 | 滑动触发的 AppleScript |
| `sourceBash` | Source | Shell 脚本 | nil | 否 | 滑动触发的 Shell 脚本 |

#### `expandable` — 可展开容器

可展开的卡片容器，点击显示子项，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `title` | text | 任意 | `"More"` | 否 | 容器名称 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `items` | BarItemDefinition[] | 子项数组 | — | **是(仅JSON)** | 嵌套的 widget 定义 |
| `closePosition` | selection | `"left"` / `"right"` | `"left"` | 否 | 关闭按钮位置 |
| `cardWidthRatio` | number | 0.0~1.0 | 0.5 | 否 | 卡片宽度占 Touch Bar 的比例 |

**子项特殊属性**：子项可设 `"divider": true` 显示分隔线。

---

### 4.8 开发者 (Dev)

#### `networkSpeed` — 网速

实时网络上传/下载速度。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `refreshInterval` | integer | 秒 | 2 | 否 | 刷新间隔 |
| `units` | selection | `"auto"` / `"MB/s"` / `"KB/s"` | `"auto"` | 否 | 显示单位 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `gitStatus` — Git

显示 Git 仓库状态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `repoPath` | text | 仓库路径 | `""` | 否 | 留空用当前目录 |
| `refreshInterval` | integer | 秒 | 10 | 否 | 刷新间隔 |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `apiLatency` — API 延迟

API 延迟监控。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `endpoint` | text | HTTP URL | `""` | 否 | 监控端点 |
| `refreshInterval` | integer | 秒 | 15 | 否 | 刷新间隔 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `windowSnap` — 窗口分屏

窗口吸附/分屏工具。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `sshStatus` — SSH

SSH 连接状态监控，支持多主机。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `host` | text | 主机地址 | `""` | 否 | 单主机 |
| `hosts` | text | 逗号分隔的主机列表 | `""` | 否 | 仅JSON，多主机（如 `"192.168.1.1,10.0.0.1"`） |
| `refreshInterval` | integer | 秒 | 20 | 否 | 刷新间隔 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

**优先级**：`hosts` > `host` > 设置里的 SSH 主机。多主机时显示「N/M 在线」。

---

### 4.9 极客 (Geek)

#### `portChecker` — 端口检查

检查端口开放状态，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `defaultPort` | integer | 端口号 | 8080 | 否 |
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `httpCodes` — HTTP 状态码

HTTP 状态码速查，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `regexTester` — 正则测试

正则表达式测试工具，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `timestampConvert` — 时间戳

时间戳转换工具，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 96 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `uuidGen` — UUID

生成 UUID。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `length` | integer | 正整数 | 16 | 否 | UUID 长度 |
| `includeSymbols` | boolean | true/false | true | 否 | 是否包含符号 |
| `width` | integer | pt | 88 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `qrCode` — 二维码

生成/扫描二维码，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 44 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `apiTester` — API 测试

API 请求测试工具，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `defaultUrl` | text | HTTP URL | `""` | 否 |
| `width` | integer | pt | 64 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.10 工具箱 (Tools)

#### `base64Tool` — Base64

Base64 编解码，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `mode` | selection | `"encode"` / `"decode"` | `"encode"` | 否 |
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `jsonFormatter` — JSON 格式化

JSON 格式化工具，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `hashCalc` — 哈希

哈希计算器，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `algorithm` | selection | `"MD5"` / `"SHA1"` / `"SHA256"` / `"SHA512"` | `"SHA256"` | 否 |
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `colorConvert` — 颜色

颜色格式转换，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `regexReference` — 正则参考

正则表达式参考，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.11 生活 (Life)

#### `packageTracker` — 快递

快递物流追踪（需快递100 API key）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `company` | text | 快递公司编码 | `"auto"` | 否 | 如 `"shunfeng"` / `"yuantong"` / `"zhongtong"` |
| `trackingNumber` | text | 快递单号 | `""` | 否 | |
| `refreshInterval` | integer | 秒 | 30 | 否 | 需在「设置 → 服务」配置快递100 key |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `foodDelivery` — 外卖

外卖配送状态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 30 | 否 |
| `width` | integer | pt | 110 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `weatherOutfit` — 穿搭

穿衣建议（基于 open-meteo 天气数据）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `lat` | text | 纬度 | `"39.9"` | 否 | 默认北京 |
| `lon` | text | 经度 | `"116.4"` | 否 | 默认北京 |
| `refreshInterval` | integer | 秒 | 60 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `noiseMeter` — 分贝

环境噪音分贝仪。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `refreshInterval` | integer | 秒 | 1 | 否 | 需麦克风权限 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `expenseTracker` — 记账

记账/支出追踪，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 expenses.json |
| `categories` | text | 逗号分隔分类 | `""` | 否 | 如 `"餐饮,交通,购物,娱乐"` |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `subscriptionCountdown` — 订阅

订阅到期倒计时。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 subscriptions.json |
| `refreshInterval` | integer | 秒 | 3600 | 否 | |
| `index` | integer | 0 起 | 0 | 否 | 仅JSON，显示第几个订阅 |
| `tint` | text | 颜色名 | `""` | 否 | 仅JSON，可选: `"mint"` / `"coral"` / `"sky"` / `"gold"` / `"purple"` / `"pink"` |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

---

### 4.12 健康 (Health)

#### `breathingGuide` — 呼吸训练

呼吸训练引导，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `pattern` | selection | `"4-7-8"` / `"Box"` / `"Coherent"` | `"4-7-8"` | 否 | 呼吸节奏模式 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

**模式说明**：
- `4-7-8` — 吸4秒、屏7秒、呼8秒（安神助眠）
- `Box` — 各4秒（方形呼吸）
- `Coherent` — 相干呼吸（每分钟5~6次）

#### `postureReminder` — 久坐提醒

久坐提醒。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `intervalMin` | integer | 分钟 | 45 | 否 | 提醒间隔 |
| `refreshInterval` | integer | 秒 | 30 | 否 | |
| `width` | integer | pt | 100 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `travelCountdown` — 出行

出行倒计时（基于日历事件）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `calendarFilter` | text | 日历过滤器 | `""` | 否 | EventKit 过滤 |
| `refreshInterval` | integer | 秒 | 60 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `birthdayCountdown` — 生日

生日倒计时。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 birthdays.json |
| `refreshInterval` | integer | 秒 | 3600 | 否 | |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `holidayCountdown` — 假期

节假日倒计时。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 3600 | 否 |
| `width` | integer | pt | 120 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `dailyQuote` — 一言

每日一言/语录（hitokoto API）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 600 | 否 |
| `width` | integer | pt | 160 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `screenLock` — 锁屏

一键锁屏。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 72 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.13 办公 (Office)

#### `emailBadge` — 邮件

未读邮件数。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 120 | 否 |
| `width` | integer | pt | 96 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `meetingCountdown` — 会议

会议倒计时（EventKit）。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 30 | 否 |
| `width` | integer | pt | 130 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `slackUnread` — Slack

Slack 未读消息。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `channels` | text | 频道名 | `""` | 否 | 如 `"general"` |
| `refreshInterval` | integer | 秒 | 120 | 否 | 需 Slack API key |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `printerStatus` — 打印机

打印机状态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 60 | 否 |
| `width` | integer | pt | 100 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `standupTimer` — 站会

站会计时器。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `durationMin` | integer | 分钟 | 15 | 否 |
| `width` | integer | pt | 96 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `clipboardHistory` — 剪贴板

剪贴板历史，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `maxItems` | integer | 正整数 | 5 | 否 |
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.14 校园 (Campus)

#### `classCountdown` — 课程

课程倒计时。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 classes.json |
| `refreshInterval` | integer | 秒 | 60 | 否 | |
| `width` | integer | pt | 130 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `ddlList` — DDL

DDL 截止日列表，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 ddls.json |
| `refreshInterval` | integer | 秒 | 300 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `readingProgress` — 读书

阅读进度。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 reading.json |
| `refreshInterval` | integer | 秒 | 300 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `wordLookup` — 查词

查词/翻译，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `provider` | selection | `"dictionary"` / `"deepseek"` | `"dictionary"` | 否 | 词典/AI 来源 |
| `width` | integer | pt | 88 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `readTimer` — 计时

阅读计时器。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `noteCapture` — 笔记

快速笔记，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `filePath` | text | 文件路径 | `""` | 否 |
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `latexSymbols` — LaTeX

LaTeX 符号面板，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 64 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `citationGen` — 引用

引用格式生成，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `style` | selection | `"both"` / `"APA"` / `"GB-T7714"` | `"both"` | 否 | 引用格式 |
| `width` | integer | pt | 64 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `paperProgress` — 论文

论文写作进度。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `dataPath` | text | 文件路径 | `""` | 否 |
| `refreshInterval` | integer | 秒 | 5 | 否 |
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `paperTags` — 标签

论文标签管理，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `dataPath` | text | 文件路径 | `""` | 否 |
| `width` | integer | pt | 64 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.15 财务 (Finance)

#### `billSplit` — AA 分账

AA 分账计算，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `savingsGoal` — 储蓄

储蓄目标进度。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 savings.json |
| `refreshInterval` | integer | 秒 | 600 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `taxEstimate` — 个税

个税估算。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `annualIncome` | text | 数字字符串 | `"300000"` | 否 | 年收入（元） |
| `refreshInterval` | integer | 秒 | 3600 | 否 | |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `creditCardDue` — 信用卡

信用卡还款提醒。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `dataPath` | text | 文件路径 | `""` | 否 | 留空用默认 creditcards.json |
| `refreshInterval` | integer | 秒 | 3600 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

---

### 4.16 运维 (Ops)

#### `dockerStatus` — Docker

Docker 容器状态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `refreshInterval` | integer | 秒 | 15 | 否 | 需 docker CLI |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `ciPipeline` — CI/CD

CI/CD 流水线状态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `repo` | text | owner/repo | `""` | 否 | 需 GitHub API key |
| `refreshInterval` | integer | 秒 | 60 | 否 | |
| `width` | integer | pt | 110 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `serverMonitor` — 服务器

服务器监控。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `host` | text | user@host | `""` | 否 | 需 SSH key |
| `refreshInterval` | integer | 秒 | 30 | 否 | |
| `width` | integer | pt | 120 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `systemTemp` — 温度

系统温度监控。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 5 | 否 |
| `width` | integer | pt | 100 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `diskIO` — 磁盘 I/O

磁盘 I/O 监控。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 2 | 否 |
| `width` | integer | pt | 120 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.17 系统+ (System+)

#### `bluetoothToggle` — 蓝牙

蓝牙开关。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 80 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `quickScreenshot` — 截图

快捷截图。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `mode` | selection | `"region"` / `"full"` / `"window"` | `"region"` | 否 | 截图模式 |
| `width` | integer | pt | 80 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `shortcutHints` — 快捷键

快捷键提示，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 88 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `screenPicker` — 取色

屏幕取色器。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 96 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

#### `finderTags` — 标签夹

Finder 标签快速打开，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `width` | integer | pt | 64 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

### 4.18 创意 (Creative)

#### `pixelPet` — 像素宠物

像素宠物伴侣。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `petType` | selection | `"cat"` / `"dog"` / `"bird"` / `"fish"` | `"cat"` | 否 | 宠物类型 |
| `refreshInterval` | integer | 秒 | 3 | 否 | 动画刷新间隔 |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `homekitScene` — HomeKit

HomeKit 场景切换。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `scenes` | text | 逗号分隔场景名 | `""` | 否 | 如 `"回家,离家"` |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `aiSelectedText` — AI

AI 处理选中文本，有弹出界面。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `model` | text | 模型名 | `""` | 否 | 如 `"deepseek-v4-flash"` |
| `prompt` | text | 提示词 | `""` | 否 | 如 `"解释这段文字"` |
| `width` | integer | pt | 80 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `rssUnread` — RSS

RSS 未读数。

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `provider` | selection | `"feedly"` / `"inoreader"` | `""` | 否 | RSS 源 |
| `refreshInterval` | integer | 秒 | 300 | 否 | |
| `width` | integer | pt | 96 | 否 | 宽度 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 | 对齐 |

#### `bilibiliFeed` — B站

B站动态。

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | integer | 秒 | 300 | 否 |
| `width` | integer | pt | 96 | 否 |
| `align` | selection | `"left"` / `"center"` / `"right"` | `"center"` | 否 |

---

## 五、编辑器未暴露但 JSON 可用的类型

以下类型在 `ItemType` 枚举和 `BarItemFactory` 中存在，可通过直接编辑 JSON 配置使用，但**不在编辑器 Palette 中展示**：

#### `appleScriptTitledButton` — AppleScript 按钮

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `source` | Source | AppleScript 源 | — | **是** | filePath/base64/inline |
| `refreshInterval` | number | 秒 | 1800 | 否 | 刷新间隔 |
| `alternativeImages` | object | {状态名: Source} | {} | 否 | 不同状态的图标 |

#### `shellScriptTitledButton` — Shell 脚本按钮

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `source` | Source | Shell 脚本源 | — | **是** | filePath/base64/inline |
| `refreshInterval` | number | 秒 | 1800 | 否 | 刷新间隔 |

#### `yandexWeather` — Yandex 天气

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `refreshInterval` | number | 秒 | 1800 | 否 |

#### `network` — 网络监控（旧版）

| 字段 | 类型 | 接受值 | 默认值 | 必填 |
|------|------|--------|--------|------|
| `flip` | boolean | true/false | false | 否 |
| `units` | text | `"dynamic"` 等 | `"dynamic"` | 否 |

#### `usage` — 使用量监控

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `providers` | ProviderConfig[] | AI 服务商配置 | [] | 否 | 见下方 |
| `refreshInterval` | number | 秒 | 300 | 否 | |
| `displayMode` | text | `"compact"` / `"expanded"` | `"compact"` | 否 | |
| `widgetWidth` | number | pt | 120 | 否 | |

**ProviderConfig 结构**：
```json
{ "provider": "deepseek", "api_key": "sk-...", "base_url": "https://..." }
```
支持的 provider：`"deepseek"` / `"longcat"` / `"bailian"`

#### `notificationCenter` — 通知中心

| 字段 | 类型 | 接受值 | 默认值 | 必填 | 说明 |
|------|------|--------|--------|------|------|
| `refreshInterval` | number | 秒 | 15 | 否 | |
| `maxItems` | integer | 正整数 | 30 | 否 | 最大通知数 |
| `filterApps` | string[] | app bundle ID | [] | 否 | 仅显示这些 app 的通知 |
| `defaultPolicy` | text | `"showAll"` 等 | `"showAll"` | 否 | 默认策略 |
| `hiddenApps` | string[] | app bundle ID | [] | 否 | 隐藏这些 app 的通知 |

**需要 Full Disk Access 权限**。

---

## 六、内置快捷类型

以下类型在 `SupportedTypesHolder` 中预注册，使用固定的 HID 键码，不走 ItemType 解码：

| 类型 | 说明 | 触发的键码 |
|------|------|-----------|
| `delete` | Del 键 | keycode 117 |
| `brightnessUp` | 亮度+ | NX_KEYTYPE_BRIGHTNESS_UP |
| `brightnessDown` | 亮度- | NX_KEYTYPE_BRIGHTNESS_DOWN |
| `illuminationUp` | 键盘灯+ | NX_KEYTYPE_ILLUMINATION_UP |
| `illuminationDown` | 键盘灯- | NX_KEYTYPE_ILLUMINATION_DOWN |
| `volumeDown` | 音量- | NX_KEYTYPE_SOUND_DOWN |
| `volumeUp` | 音量+ | NX_KEYTYPE_SOUND_UP |
| `mute` | 静音 | NX_KEYTYPE_MUTE |
| `sleep` | 系统睡眠 | `pmset sleepnow` |
| `displaySleep` | 显示器睡眠 | `pmset displaysleepnow` |

---

## 七、Action 系统

所有 widget 可通过 `actions` 数组附加多个动作。

```json
{
  "actions": [
    { "trigger": "singleTap", "action": "openUrl", "url": "https://example.com" },
    { "trigger": "longTap", "action": "shellScript", "executablePath": "/usr/bin/say", "shellArguments": ["hello"] }
  ]
}
```

### Trigger（触发方式）

| 值 | 说明 |
|----|------|
| `singleTap` | 单击 |
| `doubleTap` | 双击 |
| `tripleTap` | 三击 |
| `longTap` | 长按 |

### Action（动作类型）

| 值 | 必填字段 | 说明 |
|----|---------|------|
| `hidKey` | `keycode` (Int32) | 发送 HID 键码 |
| `keyPress` | `keycode` (Int) | 发送虚拟按键 |
| `appleScript` | `actionAppleScript` (Source) | 执行 AppleScript |
| `shellScript` | `executablePath` + `shellArguments` | 执行 Shell 脚本 |
| `openUrl` | `url` (String) | 打开 URL |

### 遗留兼容字段

旧配置可用以下字段代替 actions 数组：

| 字段 | 对应 |
|------|------|
| `action` | 单击动作类型 |
| `actionAppleScript` | 单击 AppleScript |
| `longAction` | 长按动作类型 |
| `longActionAppleScript` | 长按 AppleScript |
| `longExecutablePath` | 长按脚本路径 |
| `longShellArguments` | 长按脚本参数 |
| `longUrl` | 长按打开 URL |

---

## 附录 A：Widget 内部参数（非 JSON 配置）

以下参数存在于 widget 的 `init()` 中，但**不在 ItemType 枚举和 JSON 解码器中暴露**，仅供单元测试注入使用：

| Widget | 参数 | 类型 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `clipboardHistory` | `pollInterval` | TimeInterval | 1.0s | 剪贴板轮询间隔（测试注入点） |
| `darkMode` | `refreshInterval` | TimeInterval | 3.0s | 外观轮询间隔（测试注入点） |

这些参数在运行时固定为默认值，JSON 配置中写入无效。

## 附录 B：API Key 依赖表

部分 widget 需要在「设置 → 服务」中配置 API key：

| Widget | 服务 | 说明 |
|--------|------|------|
| `weather` (openweather) | OpenWeatherMap | 需 API key |
| `weather` (china) | 中国天气网 | 无需 key |
| `stock` | 东方财富/腾讯 | 使用公开 API，无需 key |
| `deepseekBalance` | DeepSeek | 需 API key |
| `opencodeGoUsage` | OpenCode.ai | 需浏览器 cookie |
| `lyricsTranslate` | 翻译服务 | 需配置 |
| `packageTracker` | 快递100 | 需 key + customer |
| `slackUnread` | Slack | 需 API key |
| `sshStatus` | SSH | 需 SSH key 或密码 |
| `serverMonitor` | SSH | 需 SSH key |
| `ciPipeline` | GitHub | 需 GitHub token |
| `homekitScene` | 米家 | 需配置 |
| `rssUnread` | Feedly/Inoreader | 需 API key |
| `aiSelectedText` | DeepSeek | 需 API key |
