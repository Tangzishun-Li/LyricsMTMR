# 核验报告_第63轮_INTEG收口

> 2026-08-25，INTEG 卡 t_f3164385（分支 lyricsmtmr/t_f3164385-r63-integ-integ-r63-0.63）。
> 双执行卡：r63-a t_e50f0493（EditorTabView 死代码簇删除，用户决策 A 落地）+ r63-b t_0674e8f9（EditorSchema 类型检查治理 P1 首刀）。
> 轨道：docs/轨道文本_R63_EditorTabView死代码簇删除与EditorSchema类型检查首刀.md，验收总则=§5。

## 1. 合并链

- 基线：git fetch 后 merge origin/main（ae19658，R63 建轨提交）——本卡 worktree 原 HEAD c5f214f 与 origin/main 的分叉仅该轨道文本一提交，合并零冲突。
- 按序合并两分支：
  1. `lyricsmtmr/t_0674e8f9-r63-b-editorschema-p1-278`（tip 7d917c9）→ 合并提交 034db33
  2. `lyricsmtmr/t_e50f0493-r63-a-editortabview-pbxproj-a`（tip f2561a9）→ 合并提交 e60b3f9
- **冲突解决：0**——两卡文件交集为空（a: 删四死文件+pbxproj 摘 16 行+file-structure.zh.md:81 注释 / b: EditorSchema.swift+新测试文件+两个 r63b 工具脚本），git ort 自动合并；轨道 §3 所有权表连续第七轮实证。
- 合并后自检：四死文件已从 Editor/ 目录消失（余 DraftManager/EditorDarkSwift/EditorSchema/PropertyInspector/RibbonEditorView/TouchBarSimulatorView/VirtualKeyboard 七文件）；pbxproj grep 四文件名 0 命中；EditorSchema.swift 内 partXxx 分段构造恰 21 处。

## 2. 构建

- 整体构建（scheme MTMR, Debug, CODE_SIGNING_ALLOWED=NO）：经 r62-b 锁脚本 `sh ../scripts/build-with-lock.sh xcodebuild … build` 执行（自动注入 `-jobs 4` + COMPILER_INDEX_STORE_ENABLE=NO），**BUILD SUCCEEDED**。
- 首次调用误以 LyricsMTMR/ 为工作目录找 scripts/（锁脚本实际在仓库根 scripts/），即改按规范命令重跑——非构建失败。

## 3. 测试

- **全量回归本轮触发**（隔代规则 R63 到轮：R61 触发→R62 用户点名规则外执行→R63 按规则触发）：UnitTests scheme 全量 **685 用例 0 失败 TEST SUCCEEDED**（104.37s 一次通过；681 基线+r63-b 新增 EditorSchemaRegistryIntegrityTests 4 例；计时敏感用例无偶发）。执行命令经锁脚本串行过闸。
- 金标准延续：SchemaDomainMigrationContractTests 8/8 全绿（278 冻结锚点原样，r63-b 已实证）；新增 EditorSchemaRegistryIntegrityTests 4/4（97 类型不重不漏/palette 引用集与注册集全等/注册完整性/std 65 类型 width+align 显示分区）。

## 4. 版本

- Info.plist 0.62/487 → **0.63/488**（CFBundleShortVersionString 与 CFBundleVersion 各 +1，INTEG 版本统一动作延续）。

## 5. 锚点巡检

- `python3 scripts/anchor-patrol.py`：88 项 PASS 59 / WARN 24 / INFO 5 / **ERROR 0**（退出码 0）；REGISTRY 登记 199 行（含本报告登记行后复核仍无重复、全部登记文件在仓库根存在）。

## 6. 收口产物（六件套）

1. README 更新日志补登 v0.63（新增 2+工程与稳定性 2+版本史追加 v0.63=第 63 轮）
2. docs/轮次简报/第63轮简报.md 新建 + index.md 追加要点行（含轨道 §1 取证链转述）
3. 本报告归档 logs/第63轮/
4. docs/轮次速查.md 滚动更新（R53 滚出；「EditorTabView 死代码簇处置」候选行改写为 R63 已删除闭环；「MTMR_BUILD_JOBS 缺省复核」行保留待用户拍板；R64 候选登记）
5. iteration-log.md 第 63 轮收口记录追加 + R64 候选登记
6. file-structure.zh.md 登记行同步（logs/第63轮/ 报告行 + :81 注释行已随 r63-a 同步）

## 7. 推送

- push origin main 后 fetch 复核 main=origin/main（哈希见 iteration-log 收口记录与卡 comment）。
