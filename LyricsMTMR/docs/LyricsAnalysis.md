# LyricsKit 加密机制总结

> 基于 [LyricsKit](https://github.com/MxIris-LyricsX-Project/LyricsKit) v1.8.3 源码分析

---

## 一、搜索接口

| 对比项 | NetEase | QQMusic |
|--------|---------|---------|
| **URL** | `http://music.163.com/api/search/pc` | **API 1:** `https://c.y.qq.com/splcloud/fcgi-bin/smartbox_new.fcg` |
| | | **API 2:** `https://u.y.qq.com/cgi-bin/musicu.fcg` |
| **方法** | POST | API 1: GET / API 2: POST |
| **加密** | ❌ 无加密 | ❌ 无加密 |
| **特殊处理** | 需要先发起一次请求提取 `Set-Cookie`，第二次请求带上 Cookie | 两个 API **并行搜索**汇总结果 |
| **参数** | `s`(搜索词), `offset`, `limit=10`, `type=1` | API 1: `key`(搜索词) |
| | | API 2: JSON body `{req_1: {method: "DoSearchForQQMusicDesktop", module: "music.search.SearchCgiService", param: {num_per_page: 20, query: ...}}}` |
| **伪装** | User-Agent 伪装 Safari, Referer: `http://music.163.com/` | 无特殊伪装 |

---

## 二、歌词获取接口

| 对比项 | NetEase | QQMusic |
|--------|---------|---------|
| **URL** | `https://interface3.music.163.com/eapi/song/lyric/v1` | `https://c.y.qq.com/qqmusic/fcgi-bin/lyric_download.fcg` |
| **方法** | POST | POST |
| **加密协议** | **EAPI 自定义加密** | **QRC 三重 DES + Zlib** |
| **请求体格式** | `params={hex加密字符串}` | `musicid={id}&version=15&miniversion=82&lrctype=4` |
| **响应格式** | JSON | XML（包裹在 `<!-- ... -->` 注释中） |

### 网易云 EAPI 加密流程

```
原始参数 (id, cp, lv, kv, tv, rv, yv...)
    │ 加入 header (__csrf, appver=8.0.0, os=android, versioncode=140, ...)
    │ JSON 序列化
    ▼
body = JSON 字符串
    │
    ├─ modified_url = URL 路径中 "api"→"eapi" 替换
    │  例: /api/song/lyric/v1 → /eapi/song/lyric/v1
    │  再去掉 https://interface3.music.163.com/e → /
    │
    ├─ message = "nobody{modified_url}use{body}md5forencrypt"
    ├─ digest  = MD5(message)              ← 16 进制小写
    │
    ▼
data = "{modified_url}-36cd479b6b5-{body}-36cd479b6b5-{digest}"
    │
    ▼
encrypted = AES-128-ECB(data, key="e82ckenh8dichen8", padding=PKCS7)
    │
    ▼
params = encrypted.toHexString()           ← 大写 HEX
    │
    ▼
最终 POST: params={hex}
```

### QQMusic QRC 解密流程

```
响应 XML 中提取到的 hex 字符串 (如 "A1B2C3D4...")
    │
    ▼
转换为 [UInt8] 字节数组
    │
    ├── STEP 1: DES 解密 (key = "!@#)(*$%^&abcDEF")         ← KEY3
    ├── STEP 2: DES 加密 (key = "123ZXC!@#)(*$%^&")          ← KEY2
    ├── STEP 3: DES 解密 (key = "!@#)(NHLiuy*$%^&")          ← KEY1
    │    （注：DES = Data Encryption Standard，64位分组加密）
    │
    ▼
移除前 2 个字节
    │
    ▼
Zlib 解压缩
    │
    ▼
UTF-8 解码 → 得到 XML 字符串
    │
    ├─ 提取 <LyricContent> 属性值（原始歌词正文）
    │
    ▼
HTML 实体解码 (&#10;→\n, &#39;→', &#32;→空格, &#45;→-, 等)
    │
    ▼
时间戳格式修复: [HH:MM:SS.xx] → [MM:SS.xx]（小时转分钟）
    │
    ▼
最终得到标准 LRC 格式歌词
```

---

## 三、歌词格式解析优先级

| 优先级 | NetEase | QQMusic |
|--------|---------|---------|
| **1 (最高)** | **YRC** — 逐字歌词(新版)，带逐字时间戳 | **QRC 解密后 XML** → 提取 `orig`（原文歌词） |
| **2** | **KRC** — 逐字歌词(旧版)，带逐字时间戳 | 同上 → 提取 `ts`（翻译歌词）合并 |
| **3** | **标准 LRC** — 普通时间戳格式 | 时间戳格式修复 `[HH:MM:SS]` → `[MM:SS]` |
| **翻译** | `tlyric` → `forceMerge`/`merge` | `ts` → `merge(translation:)` |

---

## 四、封面获取

| 对比项 | NetEase | QQMusic |
|--------|---------|---------|
| **获取方式** | 搜索响应中**直接包含** `album.picUrl` | 需要**额外调用**歌曲详情 API |
| **额外接口** | 无 | `POST u.y.qq.com/cgi-bin/musicu.fcg` → `get_song_detail_yqq` |
| **封面 URL 格式** | API 直接返回的 URL | `https://y.gtimg.cn/music/photo_new/T002R800x800M000{albumMid}.jpg` |
| **额外说明** | 无需额外网络开销 | 每次搜索歌词需多一次 HTTP 请求 |

---

## 五、加密算法参数速查

| 属性 | NetEase EAPI | QQMusic QRC |
|------|-------------|-------------|
| **对称加密** | AES-128-ECB | DES (64位) |
| **密钥 1** | `e82ckenh8dichen8` (16字节) | `!@#)(NHLiuy*$%^&` (16字节) |
| **密钥 2** | N/A | `123ZXC!@#)(*$%^&` (16字节) |
| **密钥 3** | N/A | `!@#)(*$%^&abcDEF` (16字节) |
| **填充** | PKCS7 | 无（固定8字节分组） |
| **压缩** | 无 | Zlib |
| **编码** | 最终输出 HEX 大写 | 输入为 HEX，输出为 XML |
| **额外变换** | 自定义明文格式 `nobody{url}use{body}md5forencrypt` | 移除前 2 字节 + HTML 实体解码 |
| **实现库** | CryptoSwift | 自实现 DES（包含完整的 S-Box/P-Box） |

---

## 六、关键代码文件索引

| 功能 | NetEase | QQMusic |
|------|---------|---------|
| 主 Provider | `Sources/LyricsService/Provider/Services/NetEase/NetEase.swift` | `Sources/LyricsService/Provider/Services/QQMusic/QQMusic.swift` |
| 加密客户端 | `Sources/LyricsService/Provider/Services/NetEase/NetEaseEapiClient.swift` | — |
| 解密/解析器 | `Sources/LyricsService/Parser/NetEaseKLyricParser.swift` | `Sources/LyricsService/Parser/QQMusicQrcDecrypter.swift` |
| XML 解码器 | — | `Sources/LyricsService/Provider/Services/QQMusic/QQMusicXMLDecoder.swift` |
| 请求模型 | `Sources/LyricsService/Model/NetEase/NetEaseResponseSearchResult.swift` | `Sources/LyricsService/Model/QQMusic/QQResponseSearchResult.swift` |
| 歌词模型 | `Sources/LyricsService/Model/NetEase/NetEaseResponseSingleLyrics.swift` | `Sources/LyricsService/Model/QQMusic/QQResponseSongDetail.swift` |

> 以上代码文件均位于 [LyricsKit](https://github.com/MxIris-LyricsX-Project/LyricsKit) 仓库中。
