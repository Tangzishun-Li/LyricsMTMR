# L1 检查报告 — Batch 1：系统状态类（t_77f29bac / uia1）

检查时间：2026-08-10 04:05（本机 M1 MacBook Pro 13″，macOS 15.7.7，物理 Touch Bar）
检查方式：双配置逐项静态核对 + 配置内脚本/URL/AppleScript 实机执行 + 应用实跑（MTMR 0.27 与 LyricsMTMR fork 均启动观察）+ 源码级验证（上游 Toxblh/MTMR master + 本机 fork 源码）。
注意：物理 Touch Bar 无法截图/模拟点击，Touch Bar 上的**显示效果**一律标「待确认」；但配置所引用的脚本、URL、AppleScript、系统命令均已脱离 Touch Bar 实测通过或失败。

## 0. 配置归属勘误（重要，修正父卡结论）

| 父卡说法 | 实测结论 |
|---|---|
| `~/Library/Application Support/LyricsMTMR/items.json` 是「LyricsX（歌词应用自带 Touch Bar 支持）」的配置 | **错误**。LyricsX.app（com.JH.LyricsX，v1.9.0，二进制内无 LyricsMTMR 字样）不读该目录。实际读取方是用户自研 fork **LyricsMTMR.app（bundle id Toxblh.LyricsMTMR，Xcode Debug 构建）**，源码在 `/Users/litz/codespace/MTMR with LyricsX /LyricsMTMR/`（注意目录名带尾随空格；本工作区 `MTMR with LyricsX` 只是文档落点）。该 fork 是深度定制版（中国天气网源、股票/汇率/歌词/记账等大量自定义组件） |
| LyricsMTMR 索引：内存[6][1]、CPU[6][2]、weather[6][3]、upnext[7][0]、battery[7] | **索引有误**。实测顶层 14 项：[0]themeSwitch [1]dock [2]lyrics [3]⇥组 [4]pomodoro [5]🌐组 [6]📷截图 [7]💻组（内存[7][1]/CPU[7][2]/weather[7][3]）[8]📆组（upnext[8][0]）[9]battery [10]⚙️组 [12]exitTouchbar |
| weather api_key 双配置不一致 ⚠️ | **属实**：主配置有 key，LyricsMTMR 配置为空串；且 fork 的 SecretsManager（UserDefaults `com.lyricsmtmr.services.openWeatherAPIKey`）也未配置 |

环境状态：检查开始时 MTMR 与 LyricsMTMR 均未运行（LyricsX.app 在运行）；检查后 MTMR（主）与 LyricsMTMR（fork）保持运行中（Batch2/Batch3 的并行 worker 可能要用，勿杀）；未改动任何配置（两份 items.json 已备份到 /tmp/backup_*_items.json）。

---

## 1. 内存 appleScriptTitledButton（MTMR [7][1] ≡ LyricsMTMR [7][1]，配置完全相同）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-显示 | 通过 | 配置内脚本 `ps -A -o %mem \| awk '{s+=$1}END{print int(s)}'` 实测输出 53%（本机），AppleScript 结构（`set mem to do shell script …` / `return mem & "%"`）编译运行通过。refreshInterval 5s 正常 | — |
| ① 基础交互-点击 | **失败** | actionAppleScript 目标 AX 路径过时。实测（osascript 权限已开）：`activate application "Activity Monitor"` 后 `radio button "CPU" of radio group 1 of group 2 of toolbar 1 of window 1` 报 -1719「无效的索引」。macOS 15.7.7 活动监视器 toolbar 1 结构为：[按钮×2, 菜单按钮, AXGroup①=AXRadioGroup「类别」(CPU/内存/能耗/磁盘/网络 5 个 radio button，**无 AXName 只有 AXDescription**), AXGroup②=AXButton「搜索」]。即 tab 组在 **group 1** 而非 group 2，且按名字 "CPU" 引用不到（只有描述）。另外窗口不存在时（activate 不自动开窗）同样 -1719 | 改为 `tell radio button 1 of radio group 1 of group 1 of toolbar 1 of window 1 to perform action "AXPress"`（已实测 AXPress 成功切到 CPU 页，rc=0，值变为 1,0,0,0,0）；或干脆只 `activate application "Activity Monitor"`。两处配置（主+歌词）都要改 |
| ② 内部设置 | 通过 | 参数合理：refreshInterval 5s、width 75、autoResize、ANSI 无色逻辑；`%mem` 求和口径在 macOS 上可行 | — |
| ③ 用户价值 | 保留 | 内存占用是高频查看项；但双配置**完全重复**（含同一张 base64 图标），属冗余；点击修复后价值完整 | 双配置合并时保留一份即可；修复点击脚本 |
| ④ 设置项 | 通过 | 上游 MTMR 0.27 `ItemsParsing.swift` 含 appleScriptTitledButton 类型；AppDelegate 有 `DispatchSourceFileSystemObject(eventMask: .write)` 文件监听 → 保存 items.json 后自动 reloadPreset（当场应用，无需重启）。fork 编辑器对未收录类型走 `fallback(type:)` 通用编辑（源码 `EditorSchema.swift:139`） | 修改→保存→Touch Bar 自动刷新（文件级监听），已验证到源码层，未实改配置 |

## 2. CPU shellScriptTitledButton（MTMR [7][2] ≡ LyricsMTMR [7][2]，配置完全相同）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-显示 | 通过 | `top -l 2 -n 0 -F \| egrep -o ' \d*\.\d+% idle' \| tail -1 \| awk …` 实测输出 31%（tail -1 取第二采样即瞬时值，正确）。>40% 黄、>70% 红底分支逻辑正确 | 小瑕疵：printf 结尾无 `\033[0m` 复位，若 MTMR 持续解析 ANSI，颜色可能串到后续刷新；建议补复位码 |
| ① 基础交互-点击 | **失败** | 与内存项共用同一份过时 actionAppleScript，原因/修复同第 1 项 | 同上 |
| ② 内部设置 | 通过 | refreshInterval 5s 合理；top 双采样成本约 1–2s，可接受 | — |
| ③ 用户价值 | 保留 | CPU 占用高频查看；双配置重复（冗余）；修复点击后价值完整 | 同第 1 项 |
| ④ 设置项 | 通过 | 同第 1 项（shellScriptTitledButton 在上游 ItemsParsing 有类型；文件监听热重载） | — |

## 3. weather（MTMR [7][3] 有 key / LyricsMTMR [7][3] key 为空 ⚠️）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-显示（主） | 待确认 | api_key `ca93a0bb8cdb428552660d83249e4bc9` 实测有效（openweathermap `q=Hangzhou&appid=…` 返回 200：25.9°C 中雨）。但上游 WeatherBarItem 走 **CoreLocation 定位**：TCC 24h 日志中 Toxblh.MTMR **无任何 kTCCServiceLocation 请求记录**（未授权/未触发过），若未授权则永久显示初始化占位「⏳」。需在真机上看 Touch Bar 实际显示，或检查 系统设置→隐私与安全性→定位服务→MTMR | 若长期显示 ⏳：到系统设置给 MTMR 开定位；或（更推荐，见下）fork 里改中国天气网源 |
| ① 基础交互-长按 | 通过 | 长按 `activate application "Weather"` 为标准 AppleScript，Weather.app 已安装；脚本语法验证通过 | — |
| ① 基础交互-显示（歌词） | **失败** | LyricsMTMR 配置 api_key 为空串；fork 逻辑 `api_key.isEmpty ? SecretsManager.retrieve(.openWeatherAPIKey) : api_key`（WeatherBarItem.swift:53），而 UserDefaults `com.lyricsmtmr.services.openWeatherAPIKey` **未配置**（defaults read 实测无该键）→ 空 key 请求 openweathermap 实测返回 **401 Invalid API key** → 温度解析失败，**永久显示 ⏳**。父卡 ⚠️ 确认属实 | fork 的 weather 支持 `apiSource:"china"` + `cities:["杭州"]`（内置中国天气网 358 城代码库，**免 key**，实测接口可用：d1.weather.com.cn/sk_2d/ 需 Referer，fork 已处理 ATS 例外）。建议歌词配置加这两字段并删掉 api_key |
| ② 内部设置 | 部分失败 | 主配置无 `units` 字段（默认 metric→°C 合理）、无 interval（默认 1800s 合理）、icon_type images 合理；歌词配置缺 key 且未启用 china 源（见上）；两配置均未设 apiSource/cities（默认 openweather） | 见上 |
| ③ 用户价值 | 保留（需修） | 天气为高频信息；双配置重复但 key 状态不一致（主可用/歌词必坏）。修复后歌词侧建议用免 key 的 china 源，主侧可同样切换（少一个外部依赖） | 统一为 china 源 + 城市列表，删 key |
| ④ 设置项 | 通过 | 两编辑器均有 weather schema（fork EditorSchema.swift:258，含 apiSource/cities 属性）；保存写 items.json + 文件监听热重载 | — |

## 4. battery（MTMR [9] ≡ LyricsMTMR [9]，配置完全相同）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-点击 | 通过 | `open "x-apple.systempreferences:com.apple.preference.battery"` 实测：System Settings 启动，窗口标题 AppleScript 读到「电池」（旧 URL 在 macOS 15.7.7 仍有效，无需改用 com.apple.Battery-Settings.extension） | — |
| ① 基础交互-显示 | 通过 | BatteryBarItem 为系统内置读 IOKit 电源状态，无外部依赖；本机电源实测 `pmset -g batt` 正常（100% 已充满） | — |
| ② 内部设置 | 通过 | 无内部参数；align right + #666666 底色合理 | — |
| ③ 用户价值 | 保留 | 电池+跳设置高频；双配置重复（冗余） | 合并时留一份 |
| ④ 设置项 | 通过 | 上游 ItemsParsing 有 battery 类型；fork EditorSchema 有 battery schema；热重载 ✓ | — |

## 5. timeButton（仅 MTMR [10]，歌词配置无此组件）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-显示 | 通过 | formatTemplate `MM月dd日 HH:mm` 经 NSDateFormatter 实测输出「08月10日 04:03」（CJK 字符为字面量，符合 ICU 规则）；TimeTouchBarItem 每秒 Timer 刷新 | — |
| ① 基础交互-长按 | 待确认 | 长按执行 `/usr/bin/pmset sleepnow`：pmset 存在（root:wheel 368KB）、`pmset -g batt` 正常无需特权；但**未实测长按**（会把本机睡过去，检查会中断）。逻辑本身无外部依赖，风险低 | 用户可自行长按验证 |
| ② 内部设置 | 通过 | 格式、align right、底色均合理；无时区/区域字段（用本机时区，合理） | — |
| ③ 用户价值 | 保留 | 时钟+一键睡眠是 Touch Bar 实用组合；歌词配置没有该组件属合理差异（歌词条以歌词为主） | — |
| ④ 设置项 | 通过 | 上游 ItemsParsing 有 timeButton(formatTemplate:timeZone:locale:)；fork EditorSchema 有 timeButton schema | — |

## 6. upnext（MTMR [8][0] ≡ LyricsMTMR [8][0]，配置完全相同）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互-显示 | 待确认 | 依赖 EventKit 日历权限。TCC 24h 日志中两个应用均**无 kTCCServiceCalendar 授权/拒绝记录**（授权与拒绝都会留痕），推测当前为 notDetermined 或从未触发。两实现的权限处理：上游 0.27 与 fork 的 UpNextScrubberTouchBarItem 均会在创建时 `EKEventStore.authorizationStatus` 检查并 `requestAccess(to:.event)`（上游 UpNextScrubberTouchBarItem.swift:224-226，fork :248）——即**首次运行会弹系统授权窗**，当前无人点过。若未授权则显示为空（无待办）；Touch Bar 上实际显示待用户确认 | 到 系统设置→隐私与安全性→日历，给 MTMR / LyricsMTMR 打开日历权限（首次授权弹窗出现时点「允许」）。授权后 from 0 to 12h / maxToShow 3 参数合理 |
| ② 内部设置 | 待确认 | 参数合理（0–12 小时窗口、最多 3 条、autoResize false）；日历数据源可用性取决于权限（见上） | 同上 |
| ③ 用户价值 | 保留 | 待办是 Touch Bar 经典组件；双配置重复（冗余） | 合并时留一份；授权一次即可双应用生效 |
| ④ 设置项 | 通过 | 两编辑器均有 upnext schema（fork EditorSchema「信息」分类含 upnext）；热重载 ✓ | — |

## 7. inputsource（仅 MTMR [12]，歌词配置无此组件）

| 检查项 | 状态 | 问题描述 / 证据 | 改进建议 |
|---|---|---|---|
| ① 基础交互 | 待确认（实现无风险） | InputSourceBarItem 用 TIS 私有 API（无需任何系统权限）：显示当前输入法图标/名称，单击轮换下一个可选键盘输入法（源码 InputSourceBarItem.swift:133 全部逻辑核实）。本机已启用 ABC + 简体拼音（SCIM.ITABC）+ 若干非键盘输入法，点击有实际切换对象。未能在 Touch Bar 上真机点击（无法截取 Touch Bar），但实现路径无外部依赖，失败面极小 | 用户单击验证即可 |
| ② 内部设置 | 通过 | width 50 合理；无内部参数 | — |
| ③ 用户价值 | 保留 | 输入法切换高频；仅主配置有，合理（歌词条不需要） | — |
| ④ 设置项 | 通过 | 上游 ItemsParsing 有 inputsource 类型；fork EditorSchema 有 inputsource schema | — |

---

## 8. 跨项结论（收尾任务 t_6ee736a7 关注点）

1. **必修（失败项）**：
   - 内存/CPU 的点击 actionAppleScript AX 路径过时（`group 2` → 应为 `group 1`，且 "CPU" 按名引用不到，应改 `radio button 1`）——主、歌词两份配置都改。已实测正确路径可行。
   - LyricsMTMR weather：空 key + 未配置 secret → 401 永久 ⏳。建议改 `apiSource:"china"` + `cities:["杭州"]`（免 key），或到 fork 设置里存 openWeatherAPIKey。
2. **待确认（需用户操作/真机确认）**：主 MTMR weather 显示（定位权限未知）；upnext 日历权限（首次弹窗未处理）；timeButton 长按睡眠（避免实测睡眠）；inputsource 单击（实现无风险）；Touch Bar 实际渲染效果（无法截图）。
3. **冗余**：内存/CPU/weather/battery/upnext 五组件在两配置中完全重复（含图标 base64），合并时各留一份；歌词侧 weather 建议切 china 源后与主配置保持同参。
4. **勘误**：父卡「LyricsMTMR=LyricsX 配置」归因错误，实为用户自研 fork LyricsMTMR.app（Toxblh.LyricsMTMR，Debug 构建）读取；父卡中 LyricsMTMR 组件索引整体偏移（💻=[7]、📆=[8]、battery=[9]）。
5. **运行状态**：MTMR 0.27 与 LyricsMTMR fork 实跑无崩溃无错误输出（仅一条无害的 NSStackView 高度警告）；fork 启动时经 Clash 代理出网正常。两份 items.json（JSONC，注意 URL 中的 `//` 不能按注释剥）均解析通过；备份在 /tmp/backup_MTMR_items.json、/tmp/backup_LyricsMTMR_items.json。
6. **设置面板**：所有 7 类组件均可经编辑器显式调出（上游 0.27 原生列表 + fork 自定义编辑器 schema/fallback）；保存即写回 items.json；两应用均有配置文件写事件监听（DispatchSource .write）→ 当场自动重载，无需重启。全程未实际改动配置（避免污染运行环境）。
