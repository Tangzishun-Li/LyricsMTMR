# ADR 0004：发布必须校验产物

- 状态：已采纳
- 日期：2026-11-14

## 背景

v0.3.2~v0.3.4 的 release 是空的；`SUFeedURL` 指向 `releases/latest/download/appcast.xml` 但返回 404；根目录 appcast 的 enclosure 指向不存在的 `.dmg`。CI 只跑 build+test，抓不到"构建成功但用户拿不到"。

## 决策

发布工作流在上传后运行 `verify_release.py`：资产非空、feed 可下载、版本一致、enclosure 可达、sha256 与包内 Info.plist 逐项校验；另加每日 `release-health` 哨兵。

## 取舍

发布变慢 1-2 分钟，但把"空 release"从"用户发现"提前到"发布当场失败"。

## 后果

发布事故从"上线后数周"缩短到"当场红"；历史空 release 已用同一通道修复。

## 证据

`verify_release.py`、`release-health.yml`、CI run 43594071980。
