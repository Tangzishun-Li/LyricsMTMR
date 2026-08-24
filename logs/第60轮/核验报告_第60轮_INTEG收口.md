# R60 收口核验报告（INTEG：a/b/c 三卡）

> 第 60 轮 INTEG 收口卡 t_00925f27 产出。轨道文本：docs/轨道文本_R60_启动弹窗防线与设置一致性.md（§5 验收总则/§6 收口动作清单）。

## 合并链

| 序 | 来源卡 | 分支 tip | 内容 | 冲突 |
|----|--------|----------|------|------|
| 1 | r60-a（t_cd474486） | ee70b1a | 启动 TCC 弹窗防线：AppleScriptTCCGuard 守卫（deferred 占位「▶」点按放行）+ defaultPreset.json 清理 Spotify/Music/iTunes 三组 tell application 示例块 + MusicSourceRow 未安装灰字徽标 + 两个前序运行时缺陷修复（Range.map(String.init)、放行误清 actions） | 0（fast-forward） |
| 2 | r60-b（t_e089a4cc） | 294912c | 设置项×item 全量审计交付 docs/设置项对照表_R60.md（22 tab × 87 设置项 文件:行号 级证据 0 待核）+ 死控件移除 5 处 + domainFields 补注册 notification/weather 两域 schema 化渲染（§4.4 试点） | 0（ort 自动合并） |
| 3 | r60-c（t_3d89080d） | 8cd69ae | SettingsRefreshAdvisor（§4.3 notifyChange(domain:) 归类表+≥0.5s 去抖合窗+refreshNow）+ Deck.RefreshBanner 横幅 + 五域接线 + General 黑名单缓存同步缺口修复 | pbxproj ×2（保双方） |

- merge-base 校验：ee70b1a / 294912c / 8cd69ae 全部为收口分支祖先（基线 79699ef R60 轨道文本提交）。
- 文件交集实证（§3 所有权表连续第四轮）：a∩b=∅、b∩c=∅、a∩c=`LyricsMTMR/LyricsMTMR.xcodeproj/project.pbxproj`（a 注册 AppleScriptTCCGuardTests、c 注册 SettingsRefreshAdvisorTests，各自追加行互不相干，按 §3 冲突缓冲规则保双方解清）。
- `^<<<<<<<|^>>>>>>>` 全仓源码目录残留扫描：0。

## 构建与测试

- 每卡合并后增量构建 BUILD SUCCEEDED ×3（scheme MTMR Debug, CODE_SIGNING_ALLOWED=NO, .build/DerivedData 复用）；整体构建 BUILD SUCCEEDED（c 卡合并后同一次构建即整体态）。
- 受影响套件定向（UnitTests scheme）：AppleScriptTCCGuardTests(12 新增) + SettingsRefreshAdvisorTests(10 新增) + AppleScriptDefinitionTests(5) + BarItemFactoryTests(18) + DeadSettingContractTests(5) + ItemTypeDecodeRegistryTests(173) + PollingPauseTests(5) + SettingsTabCacheTests(6) + UserDefaultsContractTests(9) = **243 用例 0 失败**，TEST SUCCEEDED。
- 全量回归：本轮不触发（轨道文本 §6 隔代规则——R59 已触发，R60 跳过，R61 为候选触发轮）。

## 版本

- Info.plist CFBundleShortVersionString 0.59 → **0.60**；CFBundleVersion 484 → **485**。
- README 更新日志补登 v0.60（当前开发版本），版本史说明序列追加 v0.60=第 60 轮。

## 锚点巡检

- python3 scripts/anchor-patrol.py 复跑：PASS 60 / WARN 23 / INFO 5 / ERROR 0，退出码 0（REGISTRY 196 → 197 行，新增本报告登记行）。本轮无 live 锚点位移（三卡改动均未触碰锚点登记区域）。

## 归档与登记

- 本报告落 logs/第60轮/；file-structure.zh.md 树形图同步登记行。
- docs/轮次简报/第60轮简报.md 新建 + index.md 追加段；docs/轮次速查.md 滚动表加 R60 行、候选段更新（SchemaBridge Phase2 候选口径更新为四域已消化；ITER-14 第 46 次核验窗口未到如实标注；新增 r60-b 移交决策项）。
- 轨道文本 R60 §8 追加 INTEG 日志行；iteration-log.md 收口记录。

## 遗留决策点（转下一轮编排者）

1. **EditorTabView 死代码簇处置（r60-b 移交）**：EditorTabView.swift+ElementPaletteView+TouchBarPreviewView+PropertiesInspectorView ~1683 行经 r57-d 定性、r60-b 复核仍为零调用死代码；本轮红线禁删仅登记，建议后续轮次开专项处置卡（删除或接线二选一，需用户拍板方向）。
2. remindEnabled/remindMinutes 展示态复核延续挂账（R59-b 登记，待 §5 审计口径）。
3. SettingsRefreshAdvisor 归类表未来新域默认 false（触发横幅）——后续域接入时按 §4.3 契约显式登记 true/false 即可，无额外工作。
4. ITER-14 第 46 次核验窗口未到（2026-11 国办 2027 节假日数据发布后执行）；真机冒烟系列延续挂账（含 TCC 首次点按放行真机观感、Banner 去抖合窗真机演示）。
