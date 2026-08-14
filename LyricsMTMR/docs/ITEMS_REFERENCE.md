# LyricsMTMR Items 完整参考手册

> 本文档基于源码 `ItemsParsing.swift`、`TouchBarController.swift` 及 `MTMR/Widgets/` 目录下所有 Widget 文件整理，涵盖 **全部 114 种 Item 类型**，详细说明每种 Item 的 **类型名（type）**、**宽度（width）**、**作用**、**操作方式** 及 **JSON 配置示例**。

---

## 📋 目录

- [一、全局架构概览](#一全局架构概览)
- [二、width（宽度）的作用与机制](#二width宽度的作用与机制)
- [三、Items 完整分类详解](#三items-完整分类详解)
  - [🔧 系统控制类](#1-系统控制类)
  - [🎵 媒体播放类](#2-媒体播放类)
  - [📊 信息展示类](#3-信息展示类)
  - [🧩 布局容器类](#4-布局容器类)
  - [⏱️ 计时/提醒类](#5-计时提醒类)
  - [📈 网络/开发工具类](#6-网络开发工具类)
  - [🎨 生活/娱乐类](#7-生活娱乐类)
  - [🔨 工具类](#8-工具类)
- [四、JSON 文件结构总览](#四json-文件结构总览)
- [五、操作与自定义指南](#五操作与自定义指南)

---

## 一、全局架构概览

LyricsMTMR 的 Touch Bar 配置是一个 **JSON 数组**，数组中的每个元素就是一个 **Item（控件）**。控件按数组顺序从左到右排列在 Touch Bar 上。

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│  Touch Bar 布局（从左到右）                                                          │
├────────┬──────┬───────────────────────────────────┬────────┬───────────────────────┤
│ 主题切换 │ Dock │         歌词显示（居中）            │ 其他控件 │  右侧控件              │
│  44px  │175px │            530px                  │        │                       │
└────────┴──────┴───────────────────────────────────┴────────┴───────────────────────┘
```

### 当前 items.json 中的 14 个 Items

| 序号 | type | width | align | 标题 | 简要作用 |
|:---:|:---|:---:|:---:|:---:|:---|
| 0 | `themeSwitch` | 44 | left | — | 切换主题预设 |
| 1 | `dock` | 175 | left | — | 应用 Dock 栏 |
| 2 | `lyrics` | 530 | center | — | 实时歌词显示 |
| 3 | `group` | 35 | left | ⇥ | 标签页组 |
| 4 | `pomodoro` | 75 | center | — | 番茄钟 |
| 5 | `expandable` | 75 | center | 🌐 | 快捷网址 |
| 6 | `expandable` | 75 | center | 📷 | 截图工具 |
| 7 | `expandable` | 75 | center | 💻 | 系统监控 |
| 8 | `expandable` | 75 | center | 📆 | 日历日程 |
| 9 | `battery` | auto | right | — | 电池电量 |
| 10 | `expandable` | 55 | right | ⚙️ | 系统控制 |
| 11 | `stock` | 200 | center | — | A 股行情 |
| 12 | `stock` | 200 | center | — | A 股行情 |
| 13 | `exitTouchbar` | 50 | right | ☠️ | 退出 MTMR |

### 全量 Item 类型统计

源码 `ItemsParsing.swift` 中共定义了 **114 种 Item 类型**（ItemTypeRaw 枚举 98 种 + `SupportedTypesHolder` 预定义 14 种 + `TouchBarController` 注册 2 种，含被禁用的 currency 类型；其中 holidayCountdown 为第 15 轮新增，即 97+14+2+1=114），分为以下八大类：

| 分类 | 数量 | 说明 |
|:---|:---:|:---|
| 系统控制 | 18 | Esc/亮度/键盘灯/音量/静音/睡眠/显示睡眠/锁屏/蓝牙/夜览/深色/勿扰等 |
| 媒体播放 | 8 | 播放/上一首/下一首/音乐/歌词/翻译/进度条/频谱 |
| 信息展示 | 15 | 电池/CPU/时间/天气/Yandex天气/汇率/输入法/股票/网络/网速/AI额度/系统温度/磁盘IO等 |
| 布局容器 | 4 | 分组/可展开/关闭/退出 |
| 计时/提醒 | 13 | 番茄钟/站会/阅读/久坐/呼吸/出行/生日/节假日/会议/课程/DDL/订阅/信用卡 |
| 网络/开发 | 15 | Git/API延迟/SSH/服务器/端口/HTTP/Docker/CI/正则/RSS/邮件/Slack/打印机/API测试等 |
| 生活/娱乐 | 12 | 记账/AA/储蓄/个税/外卖/快递/天气穿衣/像素宠物/每日一言/噪音/读书/B站动态 |
| 工具 | 29 | Base64/JSON/UUID/哈希/颜色/时间戳/单词/截图/剪贴板/二维码/LaTeX/引用/论文/标签等 |

---

## 二、width（宽度）的作用与机制

`width` 是 Item 最重要的布局属性，决定控件在 Touch Bar 上占据的 **像素宽度**。

### 取值规则

| 值类型 | 含义 | 示例 |
|:---:|:---|:---|
| **正整数** | 固定像素宽度 | `"width": 530` → 固定 530px |
| **auto** | 由 MTMR 根据内容自动计算 | `"width": "auto"`（如 battery） |
| **省略** | 使用 MTMR 默认宽度 | 部分控件不写 width |

### 布局对齐（align）

| align 值 | 行为 |
|:---:|:---|
| `left` | 靠左排列 |
| `center` | 居中排列 |
| `right` | 靠右排列 |

### 宽度分配示意

```
├─ left 区域 ─────────────┤├─ center 区域 ──────────────────────┤├─ right 区域 ─┤
  themeSwitch(44)           lyrics(530)                            battery(auto)
  dock(175)                 pomodoro(75)                           expandable(55)
  group(35)                 expandable×4(75×4)                     exitTouchbar(50)
                            stock×2(200×2)
```

> ⚠️ **注意**：Touch Bar 总宽度约 1002px（因机型而异），所有 Item 宽度之和不应超出此值。

---

## 三、Items 完整分类详解

### 1. 系统控制类

#### 1.1 `escape` — Esc 键

```json
{ "type": "escape", "width": 64, "align": "left" }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `width` | 64 | 固定宽度 |
| `align` | left | 靠左 |

**作用**：模拟键盘 Esc 键。
**操作**：单击 = 按下 Esc。

---

#### 1.2 `delete` — Del 键

```json
{ "type": "delete" }
```

**作用**：模拟键盘 Delete 键（keycode 117）。
**操作**：单击 = 按下 Del。

---

#### 1.3 `brightnessUp` / `brightnessDown` — 屏幕亮度

```json
{ "type": "brightnessUp" }
{ "type": "brightnessDown" }
```

**作用**：调节屏幕亮度。
**操作**：单击 = 增加/降低亮度；长按 = 连续调节。

---

#### 1.4 `illuminationUp` / `illuminationDown` — 键盘背光

```json
{ "type": "illuminationUp" }
{ "type": "illuminationDown" }
```

**作用**：调节键盘背光亮度。
**操作**：单击 = 增加/降低键盘灯亮度。

---

#### 1.5 `volumeUp` / `volumeDown` / `mute` — 音量控制

```json
{ "type": "volumeUp" }
{ "type": "volumeDown" }
{ "type": "mute" }
```

**作用**：控制系统音量和静音。
**操作**：
- `volumeUp/Down`：单击 = 增减音量
- `mute`：单击 = 切换静音

---

#### 1.6 `volume` — 音量滑块

```json
{ "type": "volume", "width": 150 }
```

**作用**：显示音量滑块，可拖动精确调节。
**操作**：拖动滑块调节音量。

---

#### 1.7 `brightness` — 亮度滑块

```json
{ "type": "brightness", "refreshInterval": 1 }
```

**作用**：显示亮度滑块。
**操作**：拖动滑块调节屏幕亮度。

---

#### 1.8 `sleep` / `displaySleep` — 系统睡眠

```json
{ "type": "sleep" }
{ "type": "displaySleep" }
```

**作用**：
- `sleep`：让整机睡眠
- `displaySleep`：仅关闭显示器
**操作**：单击触发。

---

#### 1.9 `screenLock` — 屏幕锁定

```json
{ "type": "screenLock" }
```

**作用**：一键锁定屏幕（调用 `CGSession -suspend`）。
**操作**：展开浮层 → 点击「立即锁定」。

---

#### 1.10 `bluetoothToggle` — 蓝牙开关

```json
{ "type": "bluetoothToggle" }
```

**作用**：显示蓝牙电源状态并切换（需安装 `blueutil`）。
**操作**：展开浮层 → 点击开/关。

---

#### 1.11 `nightShift` — 夜览模式

```json
{ "type": "nightShift" }
```

**作用**：开关 macOS 夜览（Night Shift）模式。
**操作**：单击切换。

---

#### 1.12 `darkMode` — 深色模式

```json
{ "type": "darkMode" }
```

**作用**：开关 macOS 深色模式。
**操作**：单击切换。

---

#### 1.13 `dnd` — 勿扰模式

```json
{ "type": "dnd" }
```

**作用**：开关 macOS 勿扰模式（Do Not Disturb）。
**操作**：单击切换。

---

### 2. 媒体播放类

#### 2.1 `play` / `previous` / `next` — 播放控制

```json
{ "type": "play" }
{ "type": "previous" }
{ "type": "next" }
```

**作用**：媒体播放控制。
**操作**：
- `play`：单击 = 播放/暂停
- `previous`：单击 = 上一首
- `next`：单击 = 下一首

---

#### 2.2 `music` — 音乐播放器

```json
{
  "type": "music",
  "refreshInterval": 2,
  "disableMarquee": false
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `refreshInterval` | 2 | 刷新间隔（秒） |
| `disableMarquee` | false | 是否禁用跑马灯 |

**作用**：显示当前播放歌曲信息（支持 Apple Music/Spotify/VOX 等）。
**操作**：单击 = 播放/暂停；长按 = 下一首。

---

#### 2.3 `lyrics` — 歌词显示

```json
{
  "type": "lyrics",
  "width": 530,
  "align": "center",
  "displayMode": "karaoke",
  "karaokeStyle": "progressive",
  "showArtwork": true,
  "clickAction": "original",
  "marqueeStyle": "marquee"
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `displayMode` | karaoke | 显示模式（karaoke = 卡拉 OK） |
| `karaokeStyle` | progressive | 渐进式填充 |
| `showArtwork` | true | 显示专辑封面 |
| `clickAction` | original | 点击打开原始播放器 |
| `marqueeStyle` | marquee | 跑马灯样式 |

**作用**：实时显示歌词，支持卡拉 OK 逐字高亮。数据来源为 LyricsX。
**操作**：单击 = 打开播放器；自动随音乐滚动。

---

#### 2.4 `lyricsTranslate` — 歌词翻译

```json
{ "type": "lyricsTranslate" }
```

**作用**：长按翻译当前歌词行（使用 mymemory 免费翻译 API）。
**操作**：长按 → 浮层显示翻译结果。

---

#### 2.5 `playbackProgress` — 播放进度条

```json
{ "type": "playbackProgress" }
```

**作用**：显示当前播放进度条（渐变填充 + 发光播放头）。
**操作**：显示进度，不可交互。

---

#### 2.6 `audioSpectrum` — 音频频谱

```json
{ "type": "audioSpectrum", "barCount": 16 }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `barCount` | 16 | 频谱条数量 |

**作用**：实时音频频谱可视化（CoreAudio + FFT）。
**操作**：自动随音乐跳动。

---

### 3. 信息展示类

#### 3.1 `battery` — 电池状态

```json
{
  "type": "battery",
  "action": "openUrl",
  "url": "x-apple.systempreferences:com.apple.preference.battery",
  "align": "right"
}
```

**作用**：显示电池电量百分比和充电状态。
**操作**：单击 = 打开系统设置 → 电池。

---

#### 3.2 `cpu` — CPU 负载

```json
{ "type": "cpu", "refreshInterval": 5 }
```

**作用**：显示 CPU 占用率，颜色随负载变化。
**操作**：单击 = 打开活动监视器。

---

#### 3.3 `timeButton` — 时间显示

```json
{
  "type": "timeButton",
  "formatTemplate": "HH:mm",
  "locale": "en_GB",
  "timeZone": "UTC"
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `formatTemplate` | HH:mm | 时间格式模板 |
| `locale` | — | 地区设置 |
| `timeZone` | — | 时区 |

**作用**：显示当前时间/日期。
**操作**：单击可触发自定义动作。

---

#### 3.4 `weather` — 天气

```json
{
  "type": "weather",
  "refreshInterval": 600,
  "units": "metric",
  "icon_type": "text",
  "api_key": "YOUR_API_KEY"
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `refreshInterval` | 600 | 刷新间隔（秒） |
| `units` | metric | 单位（metric=摄氏 / imperial=华氏） |
| `icon_type` | text | 图标类型（text/images） |
| `api_key` | — | OpenWeatherMap API Key |

**作用**：显示当前天气（需 OpenWeatherMap API Key）。
**操作**：自动刷新。

---

#### 3.5 `yandexWeather` — Yandex 天气

```json
{ "type": "yandexWeather", "refreshInterval": 600 }
```

**作用**：显示 Yandex 天气信息。
**操作**：单击 = 在浏览器打开天气预报。

---

#### 3.6 `currency` — 汇率

```json
{
  "type": "currency",
  "refreshInterval": 600,
  "from": "RUB",
  "to": "USD",
  "full": false
}
```

**作用**：显示汇率（数据源 Coinbase；网络不可用/解析失败时显示 ⚠︎ 错误态，不崩溃）。

---

#### 3.7 `inputsource` — 输入法

```json
{ "type": "inputsource" }
```

**作用**：显示当前输入法图标/名称。
**操作**：单击 = 切换输入法。

---

#### 3.8 `stock` — A 股行情

```json
{
  "type": "stock",
  "width": 200,
  "stocks": ["sh603568"],
  "apiSource": "tencent",
  "displayMode": "compact",
  "refreshInterval": 10,
  "textWidth": 70,
  "chartWidth": 130,
  "showChart": true,
  "chartMode": "fenzhong"
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `stocks` | — | 股票代码数组 |
| `apiSource` | tencent | 数据源 |
| `displayMode` | compact | 紧凑显示 |
| `refreshInterval` | 10 | 刷新间隔（秒） |
| `chartMode` | fenzhong | 分时图模式 |
| `showChart` | true | 显示分时图 |

**作用**：实时显示 A 股行情 + 分时图。
**操作**：自动刷新。

---

#### 3.9 `network` — 网络状态

```json
{
  "type": "network",
  "flip": false,
  "units": "dynamic"
}
```

**作用**：显示网络连接状态。

---

#### 3.10 `networkSpeed` — 实时网速

```json
{
  "type": "networkSpeed",
  "refreshInterval": 2,
  "units": "auto"
}
```

**作用**：实时显示网络下载/上传速率 + 迷你火花线。
**操作**：自动刷新。

---

#### 3.11 `usage` — AI 额度监控

```json
{
  "type": "usage",
  "providers": [
    { "provider": "deepseek", "api_key": "sk-xxx" },
    { "provider": "longcat", "api_key": "yyy" }
  ],
  "refreshInterval": 300,
  "displayMode": "compact",
  "widgetWidth": 200
}
```

**作用**：监控 AI 服务（DeepSeek/Longcat/百炼）的额度使用情况。
**操作**：自动刷新。

---

#### 3.12 `deepseekBalance` — DeepSeek 余额

```json
{
  "type": "deepseekBalance",
  "apiKey": "sk-xxx",
  "displayMode": "both",
  "showRemaining": true,
  "refreshInterval": 3600
}
```

**作用**：显示 DeepSeek API 余额/用量。
**操作**：自动刷新。

---

#### 3.13 `systemTemp` — 系统温度

```json
{ "type": "systemTemp", "refreshInterval": 5 }
```

**作用**：显示 CPU 温度（需管理员权限，否则显示 mock）。
**操作**：自动刷新。

---

#### 3.14 `diskIO` — 磁盘 I/O

```json
{ "type": "diskIO", "refreshInterval": 2 }
```

**作用**：显示磁盘读写速率 + 迷你曲线。
**操作**：自动刷新。

---

#### 3.15 `opencodeGoUsage` — OpenCode Go 用量

```json
{
  "type": "opencodeGoUsage",
  "displayMode": "worst",
  "refreshInterval": 300
}
```

**作用**：显示 OpenCode Go（opencode.ai）订阅用量：5 小时滚动窗口 / 周 / 月三个限额。
**操作**：单击弹出全宽卡片，三列并排显示用量、重置倒计时与「更新于 HH:mm」（精确到分钟）；弹窗打开期间每 25 秒自动刷新，也可点 ↻ 手动刷新。

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `displayMode` | `"worst"` | 折叠态内容：`worst`（三窗口中用量最高者）/ `rolling` / `weekly` / `monthly` / `all` |
| `refreshInterval` | `300` | 后台刷新间隔（秒），最小 60 |
| `workspaceID` | `""` | 可选。留空时自动发现并缓存 |
| `cookie` | `""` | 可选。建议改在「设置 → 服务」填写；内联时优先生效 |

> 🔑 **凭证配置**：浏览器登录 opencode.ai → 开发者工具 → Cookies，复制 `auth` 的值（`Fe26.2` 开头），粘贴到「设置 → 服务 → OpenCode Go auth Cookie」。服务器刷新 Cookie 时组件会自动回写。
> ⚠️ 组件依赖 opencode.ai 的内部接口（server function ID），若对方重新部署可能失效，届时会优雅降级为错误提示。

---

### 4. 布局容器类

#### 4.1 `group` — 分组

```json
{
  "type": "group",
  "width": 35,
  "title": "⇥",
  "bordered": false,
  "items": [
    { "type": "close" },
    { "type": "staticButton", "title": "←" },
    { "type": "staticButton", "title": "→" }
  ]
}
```

**作用**：将多个控件组合为一个可折叠组。
**操作**：单击标题展开/折叠。

---

#### 4.2 `expandable` — 可展开面板

```json
{
  "type": "expandable",
  "title": "🌐",
  "width": 75,
  "closePosition": "left",
  "cardWidthRatio": 0.6,
  "items": [...]
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `title` | — | 折叠时显示的图标/文字 |
| `closePosition` | left | 关闭按钮位置 |
| `cardWidthRatio` | 0.6 | 展开面板占 Touch Bar 宽度比例 |
| `items` | — | 子控件数组 |

**作用**：点击展开一个浮层面板，包含多个子控件。
**操作**：单击展开；点击关闭按钮折叠。

---

#### 4.3 `close` — 关闭按钮

```json
{ "type": "close", "width": 64 }
```

**作用**：关闭当前 group/expandable 面板。
**操作**：单击关闭。

---

#### 4.4 `exitTouchbar` — 退出 MTMR

```json
{ "type": "exitTouchbar", "title": "☠️", "width": 50 }
```

**作用**：退出 MTMR 应用，恢复系统默认 Touch Bar。
**操作**：单击退出。

---

### 5. 计时/提醒类

#### 5.1 `pomodoro` — 番茄钟

```json
{
  "type": "pomodoro",
  "workTime": 1800,
  "restTime": 300,
  "width": 75
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `workTime` | 1500 | 工作时长（秒） |
| `restTime` | 300 | 休息时长（秒） |

**作用**：番茄工作法计时器。
**操作**：单击开始/暂停；长按重置。

---

#### 5.2 `standupTimer` — 站会计时

```json
{ "type": "standupTimer", "durationMin": 15 }
```

**作用**：站会计时器（默认 15 分钟），带进度环。
**操作**：展开浮层 → 开始/暂停/重置。

---

#### 5.3 `readTimer` — 阅读计时

```json
{ "type": "readTimer" }
```

**作用**：阅读计时器，累计今日阅读时长。
**操作**：展开浮层 → 开始/暂停。

---

#### 5.4 `postureReminder` — 久坐提醒

```json
{
  "type": "postureReminder",
  "refreshInterval": 30,
  "intervalMin": 45
}
```

**作用**：到达设定分钟后弹出「站起来活动」提醒。
**操作**：自动计时提醒。

---

#### 5.5 `breathingGuide` — 呼吸训练

```json
{ "type": "breathingGuide", "pattern": "4-7-8" }
```

**作用**：引导 4-7-8 呼吸节奏（吸气-屏息-呼气）。
**操作**：展开浮层 → 跟随进度环呼吸。

---

#### 5.6 `travelCountdown` — 出行倒计时

```json
{
  "type": "travelCountdown",
  "refreshInterval": 60,
  "calendarFilter": "航班,高铁"
}
```

**作用**：读取日历中未来 72h 内的出行事件，显示最近一程的倒计时。
**操作**：自动刷新。

---

#### 5.7 `birthdayCountdown` — 生日倒计时

```json
{
  "type": "birthdayCountdown",
  "refreshInterval": 3600,
  "dataPath": "~/birthdays.json"
}
```

**作用**：显示最近一个生日/纪念日的倒计时，当天金色高亮。
**操作**：自动刷新。

---

#### 5.8 `meetingCountdown` — 会议倒计时

```json
{ "type": "meetingCountdown", "refreshInterval": 30 }
```

**作用**：显示下一个日历会议的标题与开始倒计时。
**操作**：自动刷新。

---

#### 5.9 `classCountdown` — 课程表倒计时

```json
{
  "type": "classCountdown",
  "refreshInterval": 60,
  "dataPath": "~/classes.json"
}
```

**作用**：读取本地课程表，显示今天下一节课的名称、教室与倒计时。
**操作**：自动刷新。

---

#### 5.10 `ddlList` — DDL 列表

```json
{
  "type": "ddlList",
  "refreshInterval": 60,
  "dataPath": "~/ddls.json"
}
```

**作用**：显示最近一个截止任务的标题与剩余天数，48h 内变红告警。
**操作**：自动刷新。

---

#### 5.11 `subscriptionCountdown` — 订阅续费倒计时

```json
{
  "type": "subscriptionCountdown",
  "refreshInterval": 3600,
  "dataPath": "~/subscriptions.json"
}
```

**作用**：显示最近一个订阅的名称与剩余天数，≤3 天变红提醒。
**操作**：自动刷新。

---

#### 5.12 `creditCardDue` — 信用卡还款

```json
{
  "type": "creditCardDue",
  "refreshInterval": 3600,
  "dataPath": "~/creditcards.json"
}
```

**作用**：显示最近一期账单的卡名、剩余天数与金额，临期提醒。
**操作**：自动刷新。

---

#### 5.13 `holidayCountdown` — 节假日倒计时

```json
{
  "type": "holidayCountdown",
  "refreshInterval": 3600
}
```

**作用**：复用 A 股交易日历法定节假日表（`StockBarItem.aShareHolidays`，2026 国办发明电〔2025〕7 号 + 2027 预估）作为唯一数据源，显示距下一个法定节假日首日的天数与假期名（元旦/春节/清明/劳动节/端午/中秋/国庆节）；假期窗口内显示「X 第 N 天」，临近（≤7 天）或假期中金色高亮。
**操作**：自动刷新；数据随 aShareHolidays 年度维护同步更新。

---

### 6. 网络/开发工具类

#### 6.1 `gitStatus` — Git 仓库状态

```json
{
  "type": "gitStatus",
  "repoPath": "~/Projects/my-repo",
  "refreshInterval": 30
}
```

**作用**：显示当前分支名与未提交变更数量。
**操作**：自动刷新。

---

#### 6.2 `apiLatency` — API 延迟

```json
{
  "type": "apiLatency",
  "endpoint": "https://api.example.com/health",
  "refreshInterval": 30
}
```

**作用**：对端点发起请求测量往返延迟，按延迟高低绿/黄/红配色。
**操作**：自动刷新。

---

#### 6.3 `sshStatus` — SSH 主机状态

```json
{
  "type": "sshStatus",
  "host": "user@example.com",
  "refreshInterval": 30
}
```

**作用**：Ping 目标主机显示在线/离线与往返延迟。
**操作**：自动刷新。

---

#### 6.4 `serverMonitor` — 服务器负载

```json
{
  "type": "serverMonitor",
  "host": "user@server.com",
  "refreshInterval": 30
}
```

**作用**：通过 SSH 读取远程服务器负载均值。
**操作**：自动刷新。

---

#### 6.5 `portChecker` — 端口占用查询

```json
{ "type": "portChecker", "defaultPort": 8080 }
```

**作用**：查询指定端口被哪个进程占用（`lsof -i :PORT`）。
**操作**：展开浮层 → 选择端口。

---

#### 6.6 `httpCodes` — HTTP 状态码速查

```json
{ "type": "httpCodes" }
```

**作用**：列出常用 HTTP 状态码，点击复制含义。
**操作**：展开浮层 → 点击状态码。

---

#### 6.7 `dockerStatus` — Docker 容器状态

```json
{ "type": "dockerStatus", "refreshInterval": 30 }
```

**作用**：显示运行中/全部容器数量。
**操作**：自动刷新。

---

#### 6.8 `ciPipeline` — CI/CD 流水线

```json
{
  "type": "ciPipeline",
  "repo": "owner/repo",
  "refreshInterval": 60
}
```

**作用**：显示 GitHub Actions 最近一次 workflow 的状态。
**操作**：自动刷新。

---

#### 6.9 `regexTester` — 正则速测

```json
{ "type": "regexTester" }
```

**作用**：以剪贴板为待测文本，选择预设正则进行匹配测试。
**操作**：展开浮层 → 选择规则。

---

#### 6.10 `regexReference` — 正则速查表

```json
{ "type": "regexReference" }
```

**作用**：列出常用正则（邮箱/手机/URL/中文/身份证/IP/日期），点击复制。
**操作**：展开浮层 → 点击复制。

---

#### 6.11 `rssUnread` — RSS 未读数

```json
{
  "type": "rssUnread",
  "provider": "feedly",
  "refreshInterval": 300
}
```

**作用**：统计 Feedly/Inoreader 未读条目总数。
**操作**：自动刷新。

---

#### 6.12 `emailBadge` — 邮件未读角标

```json
{ "type": "emailBadge", "refreshInterval": 60 }
```

**作用**：通过 AppleScript 读取 Mail 收件箱未读数。
**操作**：自动刷新。

---

#### 6.13 `slackUnread` — Slack 未读

```json
{
  "type": "slackUnread",
  "refreshInterval": 60,
  "channels": "#general,#dev"
}
```

**作用**：统计 Slack 会话数与未读。
**操作**：自动刷新。

---

#### 6.14 `printerStatus` — 打印机状态

```json
{ "type": "printerStatus", "refreshInterval": 60 }
```

**作用**：通过 CUPS 读取本机打印机状态。
**操作**：自动刷新。

---

#### 6.15 `apiTester` — API 测试器

```json
{ "type": "apiTester", "defaultUrl": "https://api.example.com" }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `defaultUrl` | "" | 预填的请求 URL |

**作用**：快速发送 GET/POST 请求，显示响应状态码和前 80 字符。
**操作**：点击打开浮层，输入/确认 URL 后发送请求。

---

### 7. 生活/娱乐类

#### 7.1 `expenseTracker` — 记账

```json
{
  "type": "expenseTracker",
  "dataPath": "~/expenses.json",
  "categories": "餐饮,交通,购物,娱乐"
}
```

**作用**：显示今日支出总额，点击分类记一笔。
**操作**：展开浮层 → 选择分类。

---

#### 7.2 `billSplit` — AA 账单

```json
{ "type": "billSplit" }
```

**作用**：读取剪贴板金额，选择人数分摊，结果写回剪贴板。
**操作**：展开浮层 → 选择人数。

---

#### 7.3 `savingsGoal` — 储蓄目标

```json
{
  "type": "savingsGoal",
  "refreshInterval": 3600,
  "dataPath": "~/savings.json"
}
```

**作用**：显示目标名称、已存/目标金额与完成度进度条。
**操作**：自动刷新。

---

#### 7.4 `taxEstimate` — 个税预估

```json
{
  "type": "taxEstimate",
  "annualIncome": 200000,
  "refreshInterval": 86400
}
```

**作用**：按中国七级超额累进税率估算全年个税。
**操作**：自动刷新。

---

#### 7.5 `foodDelivery` — 外卖进度

```json
{ "type": "foodDelivery", "refreshInterval": 30 }
```

**作用**：以进度条 + 阶段文案展示外卖状态（当前为 mock 演示）。
**操作**：自动刷新。

---

#### 7.6 `packageTracker` — 快递追踪

```json
{
  "type": "packageTracker",
  "refreshInterval": 300,
  "company": "shunfeng",
  "trackingNumber": "SF1234567890"
}
```

**作用**：调用快递100查询物流状态。
**操作**：自动刷新。

---

#### 7.7 `weatherOutfit` — 天气穿衣

```json
{
  "type": "weatherOutfit",
  "refreshInterval": 600,
  "lat": 22.18,
  "lon": 113.53
}
```

**作用**：调用 open-meteo 获取气温，给出穿搭建议。
**操作**：自动刷新。

---

#### 7.8 `pixelPet` — 像素宠物

```json
{
  "type": "pixelPet",
  "petType": "cat",
  "refreshInterval": 60
}
```

**作用**：在 Touch Bar 上养一只像素宠物（猫/狗/兔），随时间切换姿态。
**操作**：自动刷新。

---

#### 7.9 `dailyQuote` — 每日一言

```json
{ "type": "dailyQuote", "refreshInterval": 600 }
```

**作用**：调用 hitokoto 免费接口获取一句短句。
**操作**：自动刷新。

---

#### 7.10 `noiseMeter` — 环境噪音

```json
{ "type": "noiseMeter", "refreshInterval": 1 }
```

**作用**：通过麦克风采集实时估算分贝（需麦克风权限）。
**操作**：自动刷新。

---

#### 7.11 `readingProgress` — 读书进度

```json
{
  "type": "readingProgress",
  "refreshInterval": 3600,
  "dataPath": "~/reading.json"
}
```

**作用**：显示当前书名/页码/总页数与阅读百分比。
**操作**：自动刷新。

---

#### 7.12 `bilibiliFeed` — B 站动态

```json
{ "type": "bilibiliFeed", "refreshInterval": 300 }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `refreshInterval` | 300 | 刷新间隔（秒） |

**作用**：显示关注 UP 主最新视频/未读动态数；Cookie 存 `SecretsManager`（`.bilibiliCookie`），无 Cookie 时显示未配置。
**操作**：点击查看动态详情。

---

### 8. 工具类

#### 8.1 `staticButton` — 静态按钮

```json
{
  "type": "staticButton",
  "title": "点击我",
  "width": 80,
  "action": "appleScript",
  "actionAppleScript": { "inline": "display notification \"Hello!\"" }
}
```

**作用**：自定义按钮，可绑定 AppleScript/ShellScript/打开 URL 等动作。
**操作**：单击/长按触发绑定动作。

---

#### 8.2 `appleScriptTitledButton` — AppleScript 按钮

```json
{
  "type": "appleScriptTitledButton",
  "source": { "inline": "return \"Hello\"" },
  "refreshInterval": 60,
  "width": 100
}
```

**作用**：执行 AppleScript，将返回值显示为按钮标题。
**操作**：自动刷新显示脚本输出。

---

#### 8.3 `shellScriptTitledButton` — Shell 脚本按钮

```json
{
  "type": "shellScriptTitledButton",
  "source": { "inline": "echo $(date +%H:%M)" },
  "refreshInterval": 5,
  "width": 80
}
```

**作用**：执行 Shell 脚本，将返回值显示为按钮标题。
**操作**：自动刷新显示脚本输出。

---

#### 8.4 `base64Tool` — Base64 编解码

```json
{ "type": "base64Tool", "mode": "encode" }
```

**作用**：读取剪贴板文本，Base64 编码/解码，结果写回剪贴板。
**操作**：展开浮层 → 选择编码/解码。

---

#### 8.5 `jsonFormatter` — JSON 格式化

```json
{ "type": "jsonFormatter" }
```

**作用**：读取剪贴板 JSON，美化或压缩，结果写回剪贴板。
**操作**：展开浮层 → 美化/压缩。

---

#### 8.6 `hashCalc` — 哈希计算

```json
{ "type": "hashCalc", "algorithm": "sha256" }
```

**作用**：读取剪贴板文本，计算 MD5/SHA1/SHA256 摘要。
**操作**：展开浮层 → 选择算法。

---

#### 8.7 `colorConvert` — 颜色转换

```json
{ "type": "colorConvert" }
```

**作用**：读取剪贴板颜色值，HEX ↔ RGB ↔ HSL 互转。
**操作**：展开浮层 → 转换。

---

#### 8.8 `timestampConvert` — 时间戳转换

```json
{ "type": "timestampConvert" }
```

**作用**：Unix 时间戳 ↔ 人类可读时间互转。
**操作**：展开浮层 → 选择转换方向。

---

#### 8.9 `uuidGen` — UUID 生成器

```json
{ "type": "uuidGen", "length": 16, "includeSymbols": true }
```

**作用**：生成 UUID / 随机密码，复制到剪贴板。
**操作**：展开浮层 → 选择生成方式。

---

#### 8.10 `wordLookup` — 单词查询

```json
{ "type": "wordLookup", "provider": "dictionary" }
```

**作用**：查询剪贴板中单词的释义（dictionaryapi.dev 或 DeepSeek）。
**操作**：展开浮层 → 点击查询。

---

#### 8.11 `noteCapture` — 笔记快捕

```json
{ "type": "noteCapture", "filePath": "~/notes.md" }
```

**作用**：将剪贴板内容追加到本地笔记文件（带时间戳）。
**操作**：展开浮层 → 选择类型。

---

#### 8.12 `quickScreenshot` — 截图快拍

```json
{ "type": "quickScreenshot", "mode": "region" }
```

**作用**：提供区域/全屏/窗口三种截图方式，保存到桌面。
**操作**：展开浮层 → 选择截图方式。

---

#### 8.13 `screenPicker` — 屏幕取色器

```json
{ "type": "screenPicker" }
```

**作用**：截取鼠标位置像素，读取颜色 HEX/RGB 并复制。
**操作**：展开浮层 → 点击取色。

---

#### 8.14 `windowSnap` — 窗口管理

```json
{ "type": "windowSnap" }
```

**作用**：提供左半屏/右半屏/全屏三种窗口布局。
**操作**：展开浮层 → 选择布局。

---

#### 8.15 `shortcutHints` — 快捷键速查

```json
{ "type": "shortcutHints" }
```

**作用**：显示当前前台 App 的常用快捷键 Top5。
**操作**：展开浮层 → 查看。

---

#### 8.16 `homekitScene` — 智能家居

```json
{ "type": "homekitScene", "scenes": "回家,离家,睡眠" }
```

**作用**：触发米家智能家居场景。
**操作**：展开浮层 → 选择场景。

---

#### 8.17 `aiSelectedText` — AI 文本处理

```json
{
  "type": "aiSelectedText",
  "model": "deepseek-v4-flash",
  "prompt": "请润色这段文字"
}
```

**作用**：将剪贴板文本发送给 DeepSeek 模型，浮层展示回复。
**操作**：展开浮层 → 点击发送。

---

#### 8.18 `quickReply` — 快捷回复

```json
{ "type": "quickReply", "configPath": "~/quick-reply.json" }
```

**作用**：预设快捷回复消息，点击复制/粘贴。
**操作**：展开浮层 → 选择消息。

---

#### 8.19 `clipboardHistory` — 剪贴板历史

```json
{ "type": "clipboardHistory", "maxItems": 8 }
```

**作用**：后台监听剪贴板变化，保留最近 N 条文本。
**操作**：展开浮层 → 点击复制历史项。

---

#### 8.20 `themeSwitch` — 主题切换

```json
{
  "type": "themeSwitch",
  "width": 44,
  "themes": [
    { "label": "1", "preset": "theme1.json" },
    { "label": "2", "preset": "theme2.json" }
  ]
}
```

**作用**：在多种主题预设间切换。
**操作**：单击循环切换。

---

#### 8.21 `upnext` — 日历日程

```json
{
  "type": "upnext",
  "from": 0,
  "to": 12,
  "maxToShow": 3,
  "autoResize": false
}
```

**作用**：显示未来 N 小时内的日历事件。
**操作**：自动刷新。

---

#### 8.22 `dock` — 应用 Dock

```json
{ "type": "dock", "width": 175, "autoResize": false }
```

**作用**：在 Touch Bar 上显示应用快捷方式。
**操作**：单击打开；半长按打开；全长按强制退出。

---

#### 8.23 `swipe` — 滑动手势

```json
{
  "type": "swipe",
  "fingers": 2,
  "direction": "right",
  "minOffset": 10,
  "sourceApple": { "inline": "beep" }
}
```

**作用**：自定义多指滑动手势触发动作。
**操作**：在 Touch Bar 上滑动触发。

---

#### 8.24 `latexSymbols` — LaTeX 符号速查

```json
{ "type": "latexSymbols" }
```

**作用**：浮层分页展示常用数学符号，点击复制到剪贴板，也支持直接输出到焦点。
**操作**：点击符号复制 / 输出。

---

#### 8.25 `citationGen` — 引用格式生成

```json
{ "type": "citationGen", "style": "both" }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `style` | both | `APA` / `GB-T7714` / `both` |

**作用**：读取剪贴板 DOI/URL，调用 CrossRef API 解析元数据，生成 APA 7th / GB/T 7714-2015 格式引用，点击复制。
**操作**：点击生成并复制引用。

---

#### 8.26 `paperProgress` — 论文阅读进度

```json
{
  "type": "paperProgress",
  "refreshInterval": 5,
  "dataPath": "~/paper-progress.json"
}
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `refreshInterval` | 5 | 刷新间隔（秒） |
| `dataPath` | 默认路径 | 进度数据文件路径（可空） |

**作用**：浮层内手动调整当前页码/总页数，数据持久化到 `paper-progress.json`；主按钮显示 `p.12/30` 进度。
**操作**：点击打开浮层调整进度。

---

#### 8.27 `paperTags` — 文献标签管理

```json
{ "type": "paperTags", "dataPath": "~/paper-tags.json" }
```

| 属性 | 默认值 | 说明 |
|:---|:---|:---|
| `dataPath` | 默认路径 | 标签记录路径（可空） |

**作用**：快速给当前论文打标签（精读/略读/待引），笔记写入本地 Markdown；与 Finder 颜色标签无关。
**操作**：点击打开浮层打标签。

---

#### 8.28 `qrCode` — 二维码生成

```json
{ "type": "qrCode" }
```

**作用**：读取剪贴板文本生成二维码，浮层显示。
**操作**：点击打开浮层查看二维码。

---

#### 8.29 `finderTags` — Finder 标签入口

```json
{ "type": "finderTags" }
```

**作用**：动态读取 macOS Finder 标签（`com.apple.finder.plist` → `FavoriteTagNames`），点击标签按钮打开 Finder 该标签的搜索视图；支持 `finder-tag-folders.json` 自定义路径映射。
**操作**：点击标签按钮打开 Finder。

---

## 四、JSON 文件结构总览

### 主配置文件：items.json

```json
[
  { "type": "themeSwitch", "width": 44, "align": "left", "themes": [...] },
  { "type": "dock", "width": 175, "align": "left" },
  { "type": "lyrics", "width": 530, "align": "center", ... },
  { "type": "group", "width": 35, "align": "left", "items": [...] },
  { "type": "pomodoro", "width": 75, "align": "center", ... },
  { "type": "expandable", "title": "🌐", "width": 75, "items": [...] },
  { "type": "expandable", "title": "📷", "width": 75, "items": [...] },
  { "type": "expandable", "title": "💻", "width": 75, "items": [...] },
  { "type": "expandable", "title": "📆", "width": 75, "items": [...] },
  { "type": "battery", "align": "right", ... },
  { "type": "expandable", "title": "⚙️", "width": 55, "items": [...] },
  { "type": "stock", "width": 200, "stocks": ["sh603568"], ... },
  { "type": "stock", "width": 200, "stocks": ["sz002150"], ... },
  { "type": "exitTouchbar", "title": "☠️", "width": 50, "align": "right" }
]
```

### 公共属性字段

| 字段 | 类型 | 必填 | 说明 |
|:---|:---:|:---:|:---|
| `type` | string | ✅ | 控件类型 |
| `width` | number/string | 否 | 像素宽度或 `"auto"` |
| `align` | string | 否 | `left` / `center` / `right` |
| `title` | string | 否 | 按钮标题/图标 |
| `bordered` | boolean | 否 | 是否显示边框 |
| `background` | string | 否 | 背景色（十六进制） |
| `items` | array | 否 | 子控件列表（group/expandable） |
| `refreshInterval` | number | 否 | 刷新间隔（秒） |
| `action` | string | 否 | 动作类型（appleScript/openUrl/...） |
| `url` | string | 否 | 打开的 URL |

---

## 五、操作与自定义指南

### 修改配置

1. **通过 GUI**：使用 [MTMR Designer](https://josmanvis.github.io/mtmr-designer) 可视化编辑
2. **直接编辑**：修改 `~/Library/Application Support/MTMR/items.json`
3. **保存后**：MTMR 会自动重新加载配置

### 添加新 Item

在 `items.json` 数组中插入一个对象：

```json
{
  "type": "staticButton",
  "title": "我的按钮",
  "width": 80,
  "align": "center",
  "action": "appleScript",
  "actionAppleScript": {
    "inline": "display notification \"Hello!\""
  }
}
```

### 新增 Widget 类型（开发者）：注册点与对账测试

> 本节面向**开发者**（给 MTMR 代码库新增一个类型）；用户侧「在 items.json 加一个已有类型的 item」见上文「添加新 Item」。

新增一个 Widget 类型须同步 **6 处注册点** + 重跑一次生成脚本，缺一不可（第 25 轮 A 卡实证；漏改任意一处运行时才暴露——解析失败/创建失败/镜像窗异常，`RegistryReconciliationTests` 将其变为立即失败）：

1. `ItemTypeRaw` 枚举 case — `Core/ItemsParsing.swift:492-591`
2. decode switch 分支 — `Core/ItemsParsing.swift:1043-1441`
3. `identifierBase` switch 分支 — `Core/TouchBarController.swift:24-223`
4. `BarItemFactory` 创建 switch 分支 — `Core/BarItemFactory.swift:52-280`
5. （预定义类型才需要）`SupportedTypesHolder` 注册表 — `Core/ItemsParsing.swift:83-254`（`"escape"` :84 … `"displaySleep"` :244）
6. （特殊行为类型才需要）控制器运行时注册 — `Core/TouchBarController.swift:331-368`

改完后在**仓库根**重跑 `python3 generate_registry_test.py` 刷新 `MTMRTests/RegistryReconciliationTests.swift` 规范清单（98 条 + 16 注册表键），生成文件按原样提交；若新类型 decode 有必填字段，需同步脚本内 `REQUIRED_FIELDS` 表（脚本为唯一真相源，详细步骤与失效方向见 [internal-apis.zh.md §2.3](developer-guide/internal-apis.zh.md)）。

> **decode 字典驱动注册表（第 30 轮 A 卡试点 + 第 31 轮 A 卡批量迁移 + 第 32 轮 A 卡第三批推进 + 第 33 轮 A 卡第四批推进 + 第 34 轮 A 卡第五批推进，可选路径）**：`ItemType.init(from:)` 在 decode switch 前先查 `ItemType.registeredTypeDecoders` 字典（已注册 83 类型 = 试点 3：`cpu`/`battery`/`swipe` + 第 31 轮批量迁移 20：形态 A「默认值」12 = `timeButton`/`brightness`/`music`/`pomodoro`/`network`/`upnext`/`lyrics`/`stock`/`usage`/`deepseekBalance`/`networkSpeed`/`uuidGen`，形态 B「无参」6 = `volume`/`inputsource`/`nightShift`/`darkMode`/`lyricsTranslate`/`windowSnap`，形态 C「必填字段」2 = `appleScriptTitledButton`/`shellScriptTitledButton` + 第 32 轮第三批迁移 20：形态 A 14 = `dock`/`weather`/`yandexWeather`/`currency`/`playbackProgress`/`quickReply`/`gitStatus`/`apiLatency`/`sshStatus`/`portChecker`/`hashCalc`/`packageTracker`/`foodDelivery`/`weatherOutfit`，形态 B 6 = `dnd`/`jsonFormatter`/`timestampConvert`/`httpCodes`/`qrCode`/`readTimer` + 第 33 轮第四批迁移 20：形态 A 14 = `noiseMeter`/`expenseTracker`/`subscriptionCountdown`/`dailyQuote`/`emailBadge`/`meetingCountdown`/`slackUnread`/`printerStatus`/`standupTimer`/`clipboardHistory`/`wordLookup`/`dockerStatus`/`serverMonitor`/`opencodeGoUsage`，形态 B 6 = `regexTester`/`colorConvert`/`regexReference`/`screenLock`/`bluetoothToggle`/`shortcutHints` + 第 34 轮第五批迁移 20：形态 A 16 = `breathingGuide`/`postureReminder`/`travelCountdown`/`birthdayCountdown`/`holidayCountdown`/`classCountdown`/`ddlList`/`readingProgress`/`noteCapture`/`savingsGoal`/`taxEstimate`/`creditCardDue`/`ciPipeline`/`systemTemp`/`diskIO`/`quickScreenshot`，形态 B 4 = `billSplit`/`screenPicker`/`latexSymbols`/`finderTags`，闭包参数解析与 switch 分支逐字节等价）；未命中仍走 switch。已注册类型 switch 分支保留（编译期穷尽性不损失），保留不迁入的类型及理由：`staticButton`（unknown 降级目标语义特殊）/`group`/`expandable`（嵌套递归）/`themeSwitch`（SupportedTypesHolder 预注册重复键，迁入零收益）/`audioSpectrum`（含派生计算逻辑）；`base64Tool` 暂留 switch（回退路径测试锚点，待确定换锚方案后再迁）；迁移契约由手写测试 `MTMRTests/ItemTypeDecodeRegistryTests.swift`（145 用例）钉住；评估与选型理由见仓库根《评估报告_第30轮_注册表混合架构decode迁移评估.md》、《验证报告_第31轮_decode迁移扩大化.md》、《验证报告_第32轮_decode迁移第三批.md》、《验证报告_第33轮_decode迁移第四批.md》与《验证报告_第34轮_decode迁移第五批.md》。新增类型按上方六处流程走即可，是否迁入注册表不影响任何功能。

**114 口径锚点**（本条与全文「114 种 Item 类型」同源）：代码注释锚点位于 `Core/TouchBarController.swift:1174/:1185`（「≤114-item preset」注释，第 28 轮实测在位；第 27 轮 A 卡 cf6d36e 在 :758-781 插入 11 行致 :1163/:1174 → :1174/:1185）；新增类型后 98+14+2 计数变化时，本文档 :3/:59 口径句、八大类统计表与速查表须同步更新。

### 调整宽度

直接修改 `width` 值（单位：像素）：

```json
{ "type": "lyrics", "width": 600 }
```

### 切换主题

点击 Touch Bar 上的主题切换器（themeSwitch），或手动替换 `items.json` 的内容。

### 应用专属主题（Per-app bar switching）

> 自 commit 2b84be3（2026-07-30 大规模功能更新）起支持：为指定 App 绑定专属 Touch Bar 布局，前台切换到该 App 时自动加载其布局，切走时回落到默认布局（backlog issue #40）。

**机制**

- 规则表：`AppSettings.appThemeRules`（UserDefaults key `com.lyricsmtmr.appThemeRules.v2`，bundleId → AppThemeMode rawValue）；
- 布局文件：每个 App 一个 JSON 文件，位于 `~/Library/Application Support/LyricsMTMR/app-themes/<bundleId>.json`，格式与 `items.json` 完全一致（JSON 数组）；
- 切换依据：前台 App（NSWorkspace 激活/启动/退出通知）→ `TouchBarController.updateActiveApp()`；切换经 `reloadPresetAsync` 异步解析 + 防抖 + 主线程原子替换，避免快速切换时的卡顿/闪烁。

**三种模式（AppThemeMode）**

| rawValue | 模式 | 行为 |
|:---:|:---|:---|
| 0 | 始终使用（always） | 每次该 App 成为前台都强制加载其专属布局 |
| 1 | 已停用（disabled） | 规则保留但不生效（相当于临时关闭） |
| 2 | 激活时使用（onActivation） | 激活时加载；用户可手动切换主题覆盖，直到下次切换 App |

**GUI 配置入口**（二选一）

1. 状态栏菜单 →「应用专属主题」卡片（StatusBarMenuView）：为当前前台 App 创建规则（复制当前布局或空白模板）、三模式切换、编辑布局文件、删除规则；
2. 设置 →「通用」→「应用专属主题」（GeneralTabView）：规则列表（按 bundleId 排序）、添加当前前台 App、改模式、编辑、删除。

**示例**（为 QQ 音乐绑定一个只显示歌词的布局）

```json
// ~/Library/Application Support/LyricsMTMR/app-themes/com.tencent.QQMusicMac.json
[
  { "type": "lyrics", "width": 530, "align": "center" }
]
```

**行为细节**

- 未配置规则（或无规则匹配）的 App 回落到默认布局（`items.json`），歌词 bar 默认行为不受影响；
- 黑名单 App 优先于主题规则（黑名单直接隐藏 Touch Bar）；
- 布局文件被删除时，对应规则自动移除并回退默认布局；
- 用户通过 themeSwitch 手动切换主题会覆盖自动布局（onActivation 模式下次切 App 时恢复）。

### 完整 type 速查表

| 分类 | 可用 type |
|:---|:---|
| **系统控制** | `escape`, `delete`, `brightnessUp`, `brightnessDown`, `illuminationUp`, `illuminationDown`, `volumeUp`, `volumeDown`, `mute`, `volume`, `brightness`, `sleep`, `displaySleep`, `screenLock`, `bluetoothToggle`, `nightShift`, `darkMode`, `dnd` |
| **媒体播放** | `play`, `next`, `previous`, `music`, `lyrics`, `lyricsTranslate`, `playbackProgress`, `audioSpectrum` |
| **信息展示** | `battery`, `cpu`, `timeButton`, `weather`, `yandexWeather`, `currency`, `inputsource`, `stock`, `network`, `networkSpeed`, `usage`, `deepseekBalance`, `opencodeGoUsage`, `systemTemp`, `diskIO` |
| **布局容器** | `group`, `expandable`, `close`, `exitTouchbar` |
| **计时/提醒** | `pomodoro`, `standupTimer`, `readTimer`, `postureReminder`, `breathingGuide`, `travelCountdown`, `birthdayCountdown`, `holidayCountdown`, `meetingCountdown`, `classCountdown`, `ddlList`, `subscriptionCountdown`, `creditCardDue` |
| **网络/开发** | `gitStatus`, `apiLatency`, `sshStatus`, `serverMonitor`, `portChecker`, `httpCodes`, `dockerStatus`, `ciPipeline`, `regexTester`, `regexReference`, `rssUnread`, `emailBadge`, `slackUnread`, `printerStatus`, `apiTester` |
| **生活/娱乐** | `expenseTracker`, `billSplit`, `savingsGoal`, `taxEstimate`, `foodDelivery`, `packageTracker`, `weatherOutfit`, `pixelPet`, `dailyQuote`, `noiseMeter`, `readingProgress`, `bilibiliFeed` |
| **工具** | `staticButton`, `appleScriptTitledButton`, `shellScriptTitledButton`, `base64Tool`, `jsonFormatter`, `hashCalc`, `colorConvert`, `timestampConvert`, `uuidGen`, `wordLookup`, `noteCapture`, `quickScreenshot`, `screenPicker`, `windowSnap`, `shortcutHints`, `homekitScene`, `aiSelectedText`, `quickReply`, `clipboardHistory`, `themeSwitch`, `upnext`, `dock`, `swipe`, `latexSymbols`, `citationGen`, `paperProgress`, `paperTags`, `qrCode`, `finderTags` |

---

> 📌 **提示**：修改 JSON 时请确保语法正确（无尾随逗号、引号匹配），否则 MTMR 会回退到默认配置。
