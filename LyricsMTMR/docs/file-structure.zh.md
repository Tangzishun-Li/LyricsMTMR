# 仓库文件存放说明 / File Structure Guide

> 本文是仓库整理（`codex/optimize-structure-build`）之后的**文件存放权威索引**。
> 任何新增/移动文件前，先对照本表决定文件归属。

---

## 一、仓库总览（思维导图）

```mermaid
mindmap
  root((LyricsMTMR 仓库))
    工程与源码
      LyricsMTMR.xcodeproj
      MTMR 源码
        App 应用入口
        Core Touch Bar 核心
        Support 基础设施
        Widgets 领域分组
        Preferences 设置与编辑器
        LyricsIntegration 歌词
        CBridge ObjC/C 桥接
        AppleScripts 脚本资源
        Assets 图标资源
      LyricsRendering 歌词渲染
      MTMRTests 单元测试
    文档
      docs 用户/开发者文档
      ITEMS_REFERENCE
      LyricsAnalysis
    示例与工具
      examples/presets 主题预设
      tools/mr-dump 调试
      tools/virtual-keyboard 原型
      Scripts 构建与生成脚本
      archive 死代码归档
    工程配置
      .github CI
      .gitignore / .gitattributes
      Makefile 一键构建
```

## 二、目录树总览

```
.
├── .github/                          # CI（根目录才会被 GitHub 执行）
│   ├── FUNDING.yml
│   ├── scripts/
│   │   └── verify_sparkle_key.sh     # Sparkle 私钥 base64(96B) 格式校验（publish / signing-check 共用，ITER-18）
│   └── workflows/
│       ├── build-test.yml            # push/PR：构建 + 单元测试（数量以 xcodebuild test 输出为准）
│       ├── publish.yml               # v* tag：通用架构(arm64+x86_64)归档
│       └── signing-check.yml         # PR：Sparkle 私钥格式 guard 冒烟（ITER-18）
├── Makefile                          # make build / test / archive / clean
├── examples/presets/                 # 主题预设示例（theme1-15、items.json、test_lyrics_preset.json）
├── tools/
│   ├── mr-dump/                      # MediaRemote 调试工具（mr_dump + 源码 + 运行脚本）
│   └── virtual-keyboard/             # 虚拟键盘 HTML 原型
├── LyricsMTMR/                       # Xcode 工程根
│   ├── LyricsMTMR.xcodeproj
│   ├── LyricsRendering/              # 歌词渲染模块（KaraokeLabel、LyricsTouchBarItem 等）
│   ├── MTMR/
│   │   ├── App/                      # 应用入口与全局状态（AppDelegate、StatusBarMenuView、AppSettings）
│   │   ├── Core/                     # Touch Bar 核心（TouchBarController、ItemsParsing、各基础 item）
│   │   ├── Support/                  # 基础设施（SecretsManager、KeyPress、CPU、AppLog、扩展等）
│   │   ├── Widgets/                  # 全部注册 widget，按领域分组
│   │   │   ├── Media/                #   媒体播放（Music、进度、频谱、歌词翻译…）
│   │   │   ├── System/               #   系统状态与硬件控制（电池、CPU、亮度、勿扰…）
│   │   │   ├── DevOps/               #   开发运维（Git、Docker、SSH、AI 用量、API 测试…）
│   │   │   ├── Tools/                #   小工具（哈希、UUID、JSON、正则、二维码…）
│   │   │   ├── Productivity/         #   效率专注（番茄钟、笔记、剪贴板、阅读…）
│   │   │   ├── Life/                 #   生活数据（天气、股票、快递、倒计时、订阅…）
│   │   │   └── Layout/               #   布局容器（Group、ExpandableCard、ThemeSwitch）
│   │   ├── Preferences/              # 设置界面
│   │   │   ├── Editor/               #   编辑器（EditorTabView、Schema、DraftManager、预览…）
│   │   │   └── Components/           #   通用表单组件
│   │   ├── LyricsIntegration/        # 歌词搜索/匹配/封面缓存
│   │   ├── CBridge/                  # ObjC/C 桥接（TouchBar 私有 API、MediaRemote…）
│   │   ├── AppleScripts/             # 内置 .scpt 脚本资源
│   │   ├── Assets.xcassets/          # 应用图标与图片资源
│   │   ├── Base.lproj/               # Main.storyboard
│   │   ├── Resources/                # run.pl（MediaRemote 运行时脚本）
│   │   ├── Info.plist / MTMR.entitlements / defaultPreset.json
│   │   └── MTMRExceptionCatcher.h    # ObjC 异常捕获（被桥接头引用，勿移动）
│   ├── MTMRTests/                    # 单元测试套件（随新增用例增长）
│   ├── Scripts/                      # 开发脚本
│   │   ├── build.sh / test.sh / archive.sh   # 一键构建（Makefile 调用）
│   │   ├── embed-entitlements.sh             # 重新签名脚本
│   │   ├── add_files.py / fix_files.py       # pbxproj 增删文件工具（幂等）
│   │   ├── gen_themes.py / gen_functional_themes.py / update_slots.py  # 主题生成
│   │   └── fix_createitem.py                 # 一次性补 createItem 分支
│   ├── Resources/                    # 上游 MTMR README 素材（logo、截图、示例配置）
│   ├── docs/                         # 文档体系（用户册/开发者册/文件结构说明）
│   └── archive/                      # 死代码归档（duplicate-LyricsRendering、dead-functions…）
└── .gitignore / .gitattributes / README.md
```

## 三、各目录职责对照表

| 目录 | 放什么 | 不许放什么 |
|------|--------|-----------|
| `LyricsMTMR/MTMR/App/` | AppDelegate、菜单栏、全局设置 | widget、工具类 |
| `LyricsMTMR/MTMR/Core/` | Touch Bar 基础设施与基础 item | 具体领域 widget |
| `LyricsMTMR/MTMR/Support/` | 与 UI 无关的基础设施/扩展 | 业务功能 |
| `LyricsMTMR/MTMR/Widgets/<领域>/` | 新 widget 按 Media/System/DevOps/Tools/Productivity/Life/Layout 归类 | 非 widget 的通用代码 |
| `LyricsMTMR/MTMR/Preferences/Editor/` | 编辑器相关（编辑、Schema、草稿、预览、模拟器） | 设置 Tab 页 |
| `LyricsMTMR/MTMR/Preferences/` 根 | 设置 Tab 页与设置逻辑 | 编辑器组件 |
| `LyricsMTMR/Scripts/` | 构建/生成/工程工具脚本 | 运行时资源 |
| `LyricsMTMR/docs/` | 文档（zh/en） | 代码 |
| `examples/presets/` | 主题/配置示例 | 用户私有数据 |
| `tools/` | 调试工具与原型 | 参与编译的代码 |
| `LyricsMTMR/archive/` | 死代码、孤儿资源、废弃脚本 | 活跃代码 |

## 四、新增文件去哪（流程）

```mermaid
flowchart TD
  A[新增 Swift 文件] --> B{是什么?}
  B -->|应用入口/全局| C[MTMR/App]
  B -->|Touch Bar 核心| D[MTMR/Core]
  B -->|基础设施| E[MTMR/Support]
  B -->|widget| F[MTMR/Widgets/对应领域]
  B -->|设置页| G[MTMR/Preferences]
  B -->|编辑器功能| H[MTMR/Preferences/Editor]
  B -->|歌词相关| I[MTMR/LyricsIntegration]
  B -->|渲染| J[LyricsRendering]
  F --> K[用 Scripts/add_files.py 注册进 Xcode 工程]
  H --> K
  K --> L[make build + make test 验证]
```

## 五、不可移动 / 仓库外文件（重要）

| 路径 | 原因 |
|------|------|
| `~/Library/Application Support/LyricsMTMR/` | **运行时数据目录**（items.json、expenses.json、classes.json、封面缓存等），在仓库外，由 App 读写 |
| `LyricsMTMR/MTMR/MTMRExceptionCatcher.h` | 被 `CBridge/TouchBarPrivateApi-Bridging.h` 的 `#import "../MTMRExceptionCatcher.h"` 引用，且 `MTMRTryOrError` 在 3 处 Swift 中使用 |
| `LyricsMTMR/MTMR/CBridge/MediaRemoteMRBridge.m` | 构建阶段脚本按 `${SRCROOT}/MTMR/CBridge` 编译 |
| `LyricsMTMR/MTMR/Resources/run.pl` | 构建阶段脚本拷贝进 app Bundle，运行时由 `MediaRemoteAdapter` 从 `Bundle.main` 读取 |
| `LyricsMTMR/MTMR/Info.plist`、`defaultPreset.json` | `INFOPLIST_FILE` / Copy Bundle Resources 引用 |
| `LyricsMTMR/MTMR/Assets.xcassets`、`AppleScripts/`、`Base.lproj/` | 资源拷贝阶段引用 |
| `LyricsMTMR/Sparkle.framework` | 本地依赖（gitignored），`FRAMEWORK_SEARCH_PATHS` 引用 |
| `.secrets.env` | 本地密钥文件（gitignored，不入库） |

## 六、构建与产物

| 命令 | 作用 | 产物 |
|------|------|------|
| `make build` | Debug 构建 | `LyricsMTMR/.build/DerivedData/Build/Products/Debug/LyricsMTMR.app` |
| `make test` | 单元测试 | xcresult 日志 |
| `make archive` | Release 通用架构归档 | `LyricsMTMR/Release/LyricsMTMR.xcarchive`（x86_64 + arm64） |
| `make clean` | 清理产物 | — |

> `.build/`、`Release/`、`build/` 均已被 `.gitignore` 忽略，不会污染仓库。
> 旧的上游 `MTMR` 工程名（`MTMR.xcodeproj`）已不存在，构建统一使用 `LyricsMTMR.xcodeproj`。

## 七、整理记录（3 个 commit）

| Commit | 内容 |
|--------|------|
| `398f1cb` chore | 预设/工具/文档/脚本分类存放，清理垃圾与构建产物 |
| `a545a77` refactor | 源码目录分层（App/Core/Support、Editor、Widgets 领域分组） |
| `452139b` build | CI 修复、entitlements 统一、一键构建脚本（Makefile） |
