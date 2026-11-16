# Developer ID 公证与 Homebrew Cask

> 计划板第 20 条。**依赖**：Apple Developer Program 账号 + Developer ID Application 证书。
> 在拿到账号之前，这条只能把"管道与配方"准备好，验收（spctl / brew install）无法完成。

## 现在的状态

- 发布产物用 ad-hoc 深度签名（`codesign --sign -`），DMG 可以右键打开，但 `spctl` 会报
  "no Developer ID"，且在部分 macOS 上首次打开仍会被拦。
- 仓库已准备：可选公证步骤（缺 secret 自动跳过）、Cask 配方、`packaging/update-cask.sh`。

## 公证需要的 secrets

| Secret | 内容 |
| --- | --- |
| `MACOS_CERT_P12` | Developer ID Application 证书导出的 .p12，base64 |
| `MACOS_CERT_PASSWORD` | 上者密码 |
| `APPLE_ID` | 公证账号 |
| `APPLE_TEAM_ID` | Team ID |
| `APPLE_APP_PASSWORD` | App 专用密码（appleid.apple.com 生成） |

## 流程

1. 发布工作流检出 tag 后，若 `MACOS_CERT_P12` 存在：导入证书 → `codesign --deep --force --options runtime --sign "Developer ID Application"`。
2. 打 DMG → `xcrun notarytool submit --wait` → `xcrun stapler staple`。
3. `verify_release.py` 额外校验 `spctl --assess` 通过（仅在有证书时）。
4. 发版后运行 `packaging/update-cask.sh vX.Y.Z` 更新配方 sha256，再提 PR 到 homebrew-cask。

## 验收（账号就绪后）

- [ ] `spctl --assess --type execute -vv LyricsMTMR.app` → `source=Notarized Developer ID`
- [ ] DMG 首次打开不再需要右键绕过
- [ ] `brew install --cask lyricsmtmr` 安装到 `/Applications`

## 未就绪时的用户路径

见 README「安装」段：下载 DMG → 拖入应用程序 → 首次右键「打开」。
