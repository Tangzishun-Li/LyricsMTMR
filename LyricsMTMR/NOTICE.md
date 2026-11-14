# Licensing

LyricsMTMR 是 MTMR（MIT）与 LyricsX（MPL-2.0）能力的整合工程。

- **本项目自有代码**：MIT（仓库根 `LICENSE`）。
- **改编自 LyricsX 的文件**：MPL-2.0（文件级），清单与义务见仓库根
  [`THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md) §2。
- **改编自 FrameworkToolbox 的文件**：MIT，见同文件 §3。
- MPL-2.0 全文：[`LICENSES/MPL-2.0.txt`](../LICENSES/MPL-2.0.txt)。

> 更正记录（2026-11）：本文件早期版本写"整体 GPL 2.0"，部分源码头写
> "licensed under GPL 2.0"。经核对，LyricsX（[ddddxxx](https://github.com/ddddxxx/LyricsX)
> 与 [MxIris fork](https://github.com/MxIris-LyricsX-Project/LyricsX)）与
> FrameworkToolbox 的许可分别是 MPL-2.0 与 MIT，不存在 GPL 覆盖。错误标注已更正，
> 以根目录 `THIRD_PARTY_NOTICES.md` 为唯一口径。

分发二进制时，`THIRD_PARTY_NOTICES.md`、`LICENSES/MPL-2.0.txt` 与 `LICENSE`
会随 App 打进 `Contents/Resources/`，由 CI 中的 `LicenseComplianceContractTests` 校验。
