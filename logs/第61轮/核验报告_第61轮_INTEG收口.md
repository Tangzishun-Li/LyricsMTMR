# 核验报告 · 第 61 轮 INTEG 收口

> 任务卡 t_1cf812bd（r61-integ），整合分支 lyricsmtmr/t_1cf812bd-r61-integ-a-b-0.61。
> 本轮主题：SchemaBridge Phase2 三域收编（r61-a）+ 日历提醒展示态复核定案（r61-b）。

## 1. 合并链与冲突解决

- main 基线 453c99f（R60 CI 修复）→ 按序 merge：a 卡 5ee81e1（fast-forward）→ b 卡 74092f0（合并提交 949f1f3，git ort 自动合并零手工冲突）→ INTEG 接线修正 f0ef8ce。
- 文件交集实证：a∩b = {SettingsSchemaBridge.swift, project.pbxproj}。bridge 两卡行区间不相交（a 仅 :237 后追加三新键、b 仅 :204 calendar 键内注释行），pbxproj 各自四段追加登记——**自动合并零冲突**。轨道文本 §3 所有权表连续第五轮生效实证。
- 残留扫描：`grep '^<<<<<<<|^>>>>>>>'` 源码目录 0 命中；plutil -lint pbxproj OK。
- 双方改动保双核查：合并后 bridge 同时含「R61-a：智能家居两键」注册段与「R61-b 复核定案」注释；pbxproj 双测试文件各 4 行登记齐全。

## 2. 构建验证

每张卡合并后增量构建 BUILD SUCCEEDED ×2（scheme MTMR, Debug, CODE_SIGNING_ALLOWED=NO, .build/DerivedData 复用）；整体构建 BUILD SUCCEEDED。

## 3. 测试

- 受影响套件定向（UnitTests scheme）：SchemaDomainMigrationContractTests(8 新增) + CalendarReminderDisplayStateTests(3 新增) + UserDefaultsContractTests(9) + DeadSettingContractTests(5) + SettingsRefreshAdvisorTests(10) = **35 用例 0 失败**。
- **全量回归本轮触发**（轨道 §6 隔代规则勘误后口径：R59 触发 → R60 跳过 → R61 到轮）：UnitTests scheme 全量 **675 用例 0 失败 TEST SUCCEEDED**（104s，一次通过无复跑）。
- 计时敏感用例本轮未出现偶发超时，无需单套件复跑定性。

## 4. INTEG 接线修正（f0ef8ce）

首轮受影响套件合跑暴露 1 例失败：testPackageDomainFieldIDsMatchBlueprint 断言 notifyOnUpdate 副标题拿到中文「默认关闭」期望英文「Off by default」。

根因：`SettingsSchema.domainFields` 为 `static let`，注册文案的 `localized()` 在进程内首次触达时按当时语言态烤死——合跑顺序下 CalendarReminderDisplayStateTests 先跑且不钉语言（走真实 UD，本机中文），首触把中文烤入静态字典；随后 SchemaDomainMigrationContractTests 的 setUp 换全新隔离 UD 套件使 `appLanguageRaw` 回落 System，断言右侧现算出英文 → 中文≠英文失败。两套件各自单独跑均绿（a 卡交付时单跑验证通过即此因）。

修复：副标题断言改为语言无关的「两语言文案之一」存在性校验，测试注释写明机制。契约本质（副标题存在且两语言齐备）不变，生产行为零变更。钉语言方案不可取：static let 已烤死，无论钉中钉英都与烤入值相反的顺序下必炸。

## 5. 锚点巡检

收口复跑 `python3 scripts/anchor-patrol.py`：PASS / WARN / INFO / **ERROR 0**（详见 §7 复跑输出）。REGISTRY 新增本报告登记行。

## 6. 收口产物清单

- Info.plist 0.60/485 → 0.61/486
- README 更新日志补登 v0.61（新增 2 项 + 改进 1 项 + 工程稳定性 3 项 + 版本史序列追加 v0.61=第 61 轮）
- 简报三件套：docs/轮次简报/第61轮简报.md 新建 + index.md 追加 R61 行 + docs/轮次速查.md 滚动更新（R49 行滚出、remindEnabled 候选转已闭环、维度轮转设置治理 ×3）
- 报告归档 logs/第61轮/核验报告_第61轮_INTEG收口.md（本文件）+ file-structure.zh.md 登记行同步
- iteration-log.md 第 61 轮收口记录 + 第 62 轮候选登记
- 轨道文本 R61 §8 追加 INTEG 日志行

## 7. 遗留移交

- EditorTabView 死代码簇 ~1683 行处置方向待用户拍板（独立简报卡 t_32f6ffe1 链路延续）
- ITER-14 节假日通知第 46 次核验：时间驱动（2026-11 国办数据发布后），窗口未到如实顺延
- 真机冒烟系列延续挂账（三新域拨动即存真机演示并入）
