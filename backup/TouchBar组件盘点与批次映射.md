# Touch Bar 组件盘点与批次映射（父卡 t_d4ec75a1 产出）

生成时间：2026-08-10
工作区：/Users/litz/codespace/MTMR with LyricsX

---

## 0. 配置来源（实际生效配置）

| 配置文件 | 应用 | 说明 |
|---|---|---|
| `~/Library/Application Support/MTMR/items.json` | MTMR（My TouchBar My Rules） | 主配置，44 个 item（含 group 嵌套），JSONC 格式（含 // 与 /* */ 注释） |
| `~/Library/Application Support/LyricsMTMR/items.json` | LyricsX（歌词应用自带 Touch Bar 支持） | 歌词条配置，约 40 个 item，与主配置大量重复，差异：多 themeSwitch / lyrics / stock×2，少 timeButton / inputsource |
| `~/Library/Application Support/MTMR/items2.json` | （旧版备用） | 旧格式网易云音乐控制条（escape/button/mediaPlayer 网易云 上一曲/❤️/播放/下一曲/退出），**不在当前 Touch Bar 生效**，建议后续确认是否删除 |
| `~/Library/Application Support/MTMR/keyPresets.json` | MTMR | 快捷键预设（全选/复制/粘贴/截图/锁屏/切标签等），供 action 引用，非独立组件 |
| `~/Documents/trae_projects/items.json` | 开发副本 | 与主配置 items.json 同内容（trae 编辑器开发用副本） |

⚠️ 注意：主配置 `items.json` 是 JSONC（含注释），直接 json.load 会失败，解析需先去注释。

---

## 1. 完整组件清单（按配置文件 + 路径索引）

### 1.1 MTMR 主配置 `items.json`（顶层 14 项，含嵌套共 44 项）

| 路径 | type | 标题/说明 | 关键字段 |
|---|---|---|---|
| [0] | staticButton | ← 桌面左切 | appleScript: Ctrl+← (key code 123) |
| [1] | staticButton | → 桌面右切 | appleScript: Ctrl+→ (key code 124) |
| [2] | dock | Dock 应用栏 | width 175, align left |
| [3] | group ⇥ | 折叠窗口导航组 | 内含 [3][0] close, [3][1] ←, [3][2] →, [3][3] dock 780 |
| [4] | pomodoro | 番茄钟 | workTime 1800 / restTime 300, background #666666 |
| [5] | group 🌐 | 网站快捷组 | 6 个 openUrl 按钮 + close：Moodle(6000D2) FnOS(FF3333) Overleaf(339CFF) GitHub(#E91E63) Bilibili(#FF9800) 菜鸟(#4CAF50) |
| [6] | staticButton | 📷 全屏截图 | appleScript: Cmd+Shift+3 (key code 23) |
| [7] | group 💻 | 系统监控组 | 内含 close + 内存% + CPU% + weather |
| [7][1] | appleScriptTitledButton | 内存占用 % | refreshInterval 5s，ps 脚本，点击打开活动监视器(CPU 页) |
| [7][2] | shellScriptTitledButton | CPU 占用 % | refreshInterval 5s，top 脚本(>40% 黄 >70% 红底)，点击打开活动监视器 |
| [7][3] | weather | 天气 | **api_key ca93a0bb8cdb428552660d83249e4bc9**（LyricsMTMR 里为空 ⚠️），icon_type images，长按打开天气 App |
| [8] | group 📆 | 日历组 | 内含 upnext + close |
| [8][0] | upnext | 待办事件 | from 0 to 12 小时，maxToShow 3 |
| [9] | battery | 电池 | 点击打开系统设置电池页 (x-apple.systempreferences:...battery) |
| [10] | timeButton | 时钟 | formatTemplate "MM月dd日 HH:mm"，长按 pmset sleepnow 睡眠 |
| [11] | group ⚙️ | 控制组 | 13 项：close + 亮度↓↑ + 键盘灯↓↑ + 静音 + 音量↓/音量条/音量↑ + 上一曲/播放/下一曲 + close |
| [11][1] | brightnessDown | 亮度减 | |
| [11][2] | brightnessUp | 亮度加 | |
| [11][3] | illuminationDown | 键盘灯减 | |
| [11][4] | illuminationUp | 键盘灯加 | |
| [11][5] | mute | 静音 | |
| [11][6] | volumeDown | 音量减 | width 45 |
| [11][7] | volume | 音量条 | width 150 |
| [11][8] | volumeUp | 音量加 | width 45 |
| [11][9] | previous | 上一曲（媒体键） | |
| [11][10] | play | 播放/暂停（媒体键） | |
| [11][11] | next | 下一曲（媒体键） | |
| [12] | inputsource | 输入法切换 | width 50（仅主配置有） |
| [13] | exitTouchbar | ☠️ 退出 Touch Bar | width 50 |

### 1.2 LyricsMTMR 配置 `items.json`（顶层 14 项）

与主配置相同的：[0]=dock 175、[2]=group ⇥、[3]=pomodoro、[4]=group 🌐（同 6 站）、[5]=📷 截图、[6]=group 💻（close+内存+CPU+weather，**weather api_key 为空**）、[7]=group 📆（upnext）、[8]=battery、[9]=group ⚙️（同 13 项）、[12]=exitTouchbar。

差异项（仅 LyricsMTMR 有）：

| 路径 | type | 标题/说明 | 关键字段 |
|---|---|---|---|
| [0] | themeSwitch | LyricsX 主题切换 | 3 个 preset：theme1.json / theme2.json / theme3.json |
| [1] | lyrics | 歌词显示 | displayMode karaoke（逐字卡拉OK），karaokeStyle progressive，showArtwork true，width 530，点击行为 original |
| [10] | stock | 股票 sh603568（中际旭创） | displayMode compact，showChart true（分时图 chartMode fenzhong），refreshInterval 10s，width 200 |
| [11] | stock | 股票 sz002150 | 同上，width 200 |

---

## 2. 类别 / 批次映射（3 类 ↔ 3 个预设批次）

| 批次 | 检查任务 | assignee | 类别 | 组件（去重后） | 数量 |
|---|---|---|---|---|---|
| **Batch 1** | t_77f29bac | uia1 | **系统状态类** | 内存%、CPU%、weather（2 配置 key 不同⚠️）、battery、timeButton（仅主）、upnext、inputsource（仅主） | 7 |
| **Batch 2** | t_64e37329 | uia2 | **控制操作类** | brightness↓↑、illumination↓↑、mute、volume↓/条/↑、previous/play/next、📷 截图、pomodoro、exitTouchbar | 13 |
| **Batch 3** | t_a3e3b802 | uia3 | **导航与第三方类** | ←/→ 桌面切换（顶层+⇥ 组内两处实例）、dock（两处实例）、group ⇥、group 🌐（6 个网站按钮）、themeSwitch（仅歌词）、lyrics（仅歌词）、stock×2（仅歌词） | 8 类/16 实例 |

### 分类原则
- **系统状态类**：被动显示系统/环境实时状态，点击多为跳转或查看详情。
- **控制操作类**：主动即时操作，系统级开关与媒体控制，无外部依赖。
- **导航与第三方类**：窗口/桌面/应用导航、外部网站快捷入口、第三方数据内容（歌词、股票、主题）。

---

## 3. 检查模板（每个 item 按四部分逐项检查）

每个 item 输出一行检查表记录，字段：**状态（通过/失败/待确认）、问题描述、复现步骤或证据、改进建议**。

### ① 基础交互
- 能否正常点击？（短按/长按分别验证）
- 功能是否在线？（action 目标是否可达：URL 能否打开、AppleScript 是否报错、shell 脚本 exit code）
- 能否正常显示并响应？（显示内容刷新、点击后 UI/系统是否响应）

### ② 内部设置
- 内置设置/内置应用是否可用？（如 weather 依赖 api_key、upnext 依赖日历权限、dock 依赖应用列表）
- 内置配置参数是否合理？（pomodoro 时长、upnext 时间窗、stock 代码与刷新间隔、timeButton 格式）

### ③ 用户价值
- 该 item 对用户是否有足够意义？给出结论：**保留 / 优化 / 下线** 建议及理由。
- 若两个配置重复出现（主 MTMR 与 LyricsMTMR），检查是否重复冗余、是否可合并。

### ④ 设置项（MTMR 设置面板中配置该组件属性）
- 该组件能否在设置中（+ 添加组件面板 / 左侧列表选中）被显式调出？
- 修改属性后能否保存？（保存后 items.json 是否写入）
- 修改后能否当场应用？（Touch Bar 是否立即刷新）
- 若不能当场应用：需要做什么（重启 MTMR / 重新加载 preset / 手动同步）？给出明确步骤。

---

## 4. 检查注意事项（跨批次共性问题）

1. **双配置重复**：主 MTMR 与 LyricsMTMR 大部分组件重复（同 type 同参数），检查时需两个配置都验，并在结果中标注差异（若有）。
2. **weather api_key 不一致**：主配置有 key `ca93a0bb8cdb428552660d83249e4bc9`，LyricsMTMR 中为空字符串 ⚠️ —— Batch 1 必查项。
3. **重复实例**：←/→ 与 dock 在顶层和 ⇥ 组内各有一份（折叠/展开两个状态），属正常设计。
4. **items2.json**：旧版网易云控制条，当前未生效，无需检查；建议收尾时确认是否删除。
5. **JSONC 解析**：items.json 带注释，改配置时注意保持注释与逗号合法（去注释后必须是合法 JSON）。
6. **检查环境**：本机 M1 Mac（macOS 15.7.7），MTMR 与 LyricsX 需在运行状态才能实测交互；无法实测的项目标「待确认」并说明原因（如权限弹窗）。
7. **配置读写**：设置面板改动会写回 `~/Library/Application Support/MTMR/items.json`（主）或 `LyricsMTMR/items.json`（歌词），改前先备份。

---

## 5. 勘误附录（收尾复核 t_6ee736a7 于 2026-08-10 追加，批次 1-3 实测确认）

1. **配置归属**：`LyricsMTMR/items.json` 的消费方是用户自研 fork **LyricsMTMR.app**（bundle id Toxblh.LyricsMTMR，Xcode Debug 构建），**不是**原版 LyricsX.app（com.JH.LyricsX，其二进制无 themeSwitch/stock/fenzhong 等组件）。fork 源码位于 `/Users/litz/codespace/MTMR with LyricsX /LyricsMTMR/`（注意目录名带尾随空格）。
2. **LyricsMTMR 顶层索引（实测，本文档 §1.2 相应修正）**：`[0]themeSwitch [1]dock175 [2]lyrics [3]⇥组 [4]🍅 [5]🌐组 [6]📷 [7]💻组 [8]📆组 [9]battery [10]⚙️组 [11]stock sh603568 [12]stock sz002150 [13]☠️`（整体比本文档原索引差一位，⚙️ 组在 [10] 而非 [9]）。
3. **股票名错误**：sh603568=伟明环保、sz002150=正泰电源（腾讯/东财行情实测）；本文档原写"中际旭创"错误（中际旭创是 sz300308）。
4. **weather key 细节**：主配置 api_key 有效（openweather 实测 200）；LyricsMTMR 空串 + fork SecretsManager 未配置 → 401 永久 ⏳，建议切 `apiSource:"china"` + `cities:["杭州"]` 免 key。
5. **items2.json**：确认未生效（旧版网易云控制条），收尾建议删除（待用户确认，见人工清单）。
6. 完整勘误与问题清单见《最终检查汇总报告_TouchBar组件L1检查.md》。
