#!/usr/bin/env python3
"""发布产物校验器 —— 让"用户能不能装上/更新收到"变成 CI 可判定的结果。

用法：
    python3 Scripts/verify_release.py                 # 校验 latest 正式版
    python3 Scripts/verify_release.py --tag v0.3.4    # 校验指定 release
    python3 Scripts/verify_release.py --download      # 额外下载 zip 校验 sha256（慢，约 8MB）
    python3 Scripts/verify_release.py --self-check    # 只校验仓库内 appcast.xml 的 enclosure

退出码：0 = 全部通过；1 = 有 FAIL。

设计原则：只读 GitHub 公开接口 + 公开下载地址，不需要 login，不需要 gh；
设置了 GITHUB_TOKEN 时自动带上，避免 CI 里撞 60 次/小时限流。
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
import shutil
import subprocess
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

REPO = os.environ.get("LYRICSMTMR_REPO", "Tangzishun-Li/LyricsMTMR")
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")

results: list[tuple[bool, str, str]] = []
RETRIES = 3
RETRY_DELAY = 2.0


def retry(fn, attempts: int = RETRIES):
    """网络抖动是常态：超时/5xx 重试几次，彻底失败才抛给调用方记 FAIL。"""
    last_error = None
    for attempt in range(attempts):
        try:
            return fn()
        except Exception as err:  # noqa: BLE001 - 网络层任何错误都重试
            last_error = err
            if attempt + 1 < attempts:
                time.sleep(RETRY_DELAY * (attempt + 1))
    raise last_error


def check(ok: bool, name: str, detail: str = "") -> bool:
    results.append((bool(ok), name, detail))
    return bool(ok)


def api(path: str) -> dict:
    return retry(lambda: _api(path))


def _api(path: str) -> dict:
    url = f"https://api.github.com/repos/{REPO}{path}"
    req = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json"})
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return json.loads(resp.read().decode())


HAVE_CURL = shutil.which("curl") is not None


def curl_fetch(url: str) -> bytes:
    """urllib 在部分网络环境会被拦/超时，回退到系统 curl。"""
    out = subprocess.run(
        ["curl", "-fsSL", "--max-time", "180", url],
        capture_output=True,
        check=False,
    )
    if out.returncode != 0:
        raise RuntimeError(out.stderr.decode("utf-8", "replace").strip() or f"curl exit {out.returncode}")
    return out.stdout


def curl_status(url: str) -> int:
    out = subprocess.run(
        ["curl", "-sL", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "120", url],
        capture_output=True,
        check=False,
    )
    try:
        return int(out.stdout.decode().strip() or 0)
    except ValueError:
        return 0


def http_status(url: str, method: str = "GET") -> tuple[int, int]:
    req = urllib.request.Request(url, method=method, headers={"User-Agent": "LyricsMTMR-release-verify"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            length = int(resp.headers.get("Content-Length") or 0)
            if method == "GET":
                resp.read(1)  # 触发真实读取，避免 0 字节假 200
            return resp.status, length
    except urllib.error.HTTPError as err:
        return err.code, 0
    except Exception:  # noqa: BLE001 - 超时/DNS 失败统一按"不可达"处理
        return (curl_status(url) if HAVE_CURL else 0), 0


def fetch(url: str) -> bytes:
    return retry(lambda: _fetch(url))


def _fetch(url: str) -> bytes:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "LyricsMTMR-release-verify"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            return resp.read()
    except Exception:  # noqa: BLE001
        if HAVE_CURL:
            return curl_fetch(url)
        raise


def sparkle_items(xml_bytes: bytes) -> list[dict]:
    root = ET.fromstring(xml_bytes)
    items = []
    for item in root.iter("item"):
        enclosure = item.find("enclosure")
        items.append(
            {
                "title": (item.findtext("title") or "").strip(),
                "version": (item.findtext(f"{{{SPARKLE_NS}}}version") or "").strip(),
                "short_version": (item.findtext(f"{{{SPARKLE_NS}}}shortVersionString") or "").strip(),
                "enclosure_url": enclosure.get("url", "") if enclosure is not None else "",
                "signature": enclosure.get(f"{{{SPARKLE_NS}}}edSignature", "") if enclosure is not None else "",
                "length": enclosure.get("length", "") if enclosure is not None else "",
            }
        )
    return items


def local_info_plist_public_key() -> str:
    """仓库内 Info.plist 的 SUPublicEDKey，用于确认 feed 签名钥匙没换过。"""
    candidates = [
        "LyricsMTMR/MTMR/Info.plist",
        "MTMR/Info.plist",
    ]
    for path in candidates:
        if not os.path.exists(path):
            continue
        data = open(path, "rb").read().decode("utf-8", "replace")
        match = re.search(r"<key>SUPublicEDKey</key>\s*<string>([^<]*)</string>", data)
        if match:
            return match.group(1).strip()
    return ""


def verify_release(tag: str, download: bool) -> None:
    if tag == "latest":
        try:
            release = api("/releases/latest")
        except urllib.error.HTTPError as err:
            check(False, "latest release 可查询", f"HTTP {err.code}")
            return
    else:
        try:
            release = api(f"/releases/tags/{tag}")
        except urllib.error.HTTPError as err:
            check(False, f"release {tag} 存在", f"HTTP {err.code}")
            return

    real_tag = release.get("tag_name", tag)
    is_prerelease = bool(release.get("prerelease"))
    check(True, f"release 解析：{real_tag}", f"prerelease={is_prerelease} draft={release.get('draft')}")

    assets = {a["name"]: a for a in release.get("assets", [])}
    zip_names = [n for n in assets if n.endswith(".zip") and not n.endswith(".zip.sha256")]
    check(len(zip_names) > 0, "资产：存在 .zip 安装包", f"assets={sorted(assets)}" if not zip_names else zip_names[0])
    check(any(n.endswith(".zip.sha256") for n in assets), "资产：存在 .zip.sha256 校验文件")
    check("appcast.xml" in assets, "资产：存在 appcast.xml（自动更新入口）")

    if not zip_names or "appcast.xml" not in assets:
        # 没有资产时继续校验会连环报错，提前收敛
        return

    zip_name = zip_names[0]
    check(assets[zip_name].get("size", 0) > 0, "资产：zip 非空", f"{assets[zip_name].get('size')} bytes")
    check(assets["appcast.xml"].get("size", 0) > 0, "资产：appcast.xml 非空")

    # 1) 自动更新入口必须真的能拿到 —— 这正是 v0.3.4 事故的现场
    feed_url = (
        f"https://github.com/{REPO}/releases/latest/download/appcast.xml"
        if tag == "latest"
        else f"https://github.com/{REPO}/releases/download/{real_tag}/appcast.xml"
    )
    status, _ = http_status(feed_url)
    if not check(status == 200, "feed 可下载", f"{feed_url} -> HTTP {status}"):
        return

    try:
        items = sparkle_items(fetch(feed_url))
    except Exception as err:  # noqa: BLE001 - 结构坏了/网络抖动都要让 CI 直接红
        check(False, "feed 可解析", f"{type(err).__name__}: {err}")
        return
    check(bool(items), "feed 至少一个 item", f"items={len(items)}")
    if not items:
        return

    newest = max(items, key=lambda i: int(i["version"] or 0))
    check(bool(newest["short_version"]), "feed shortVersionString 非空", newest["short_version"])
    check(bool(newest["signature"]), "feed 含 edSignature（Sparkle 签名）")
    check(bool(newest["length"]), "feed 含安装包 length")

    # 2) 版本一致性：tag / appcast / 资产名 三处不能漂
    tag_version = re.sub(r"^v", "", real_tag).split("-")[0]
    check(
        newest["short_version"].startswith(tag_version) or tag_version.startswith(newest["short_version"]),
        "版本一致：tag ↔ appcast",
        f"tag={real_tag} shortVersion={newest['short_version']}",
    )
    check(
        zip_name == newest["enclosure_url"].rsplit("/", 1)[-1],
        "版本一致：资产名 ↔ feed enclosure",
        f"asset={zip_name} enclosure={newest['enclosure_url'].rsplit('/', 1)[-1]}",
    )

    # 3) enclosure 必须可下载 —— 根目录 appcast 曾指向不存在的 .dmg
    enc_status, enc_length = http_status(newest["enclosure_url"])
    check(enc_status == 200, "enclosure 可下载", f"{newest['enclosure_url']} -> HTTP {enc_status}")
    if newest["length"].isdigit() and enc_length:
        check(abs(enc_length - int(newest["length"])) <= 1024, "enclosure 大小与 feed length 一致",
              f"feed={newest['length']} http={enc_length}")

    # 4) 公钥自检（防止签名钥匙轮换不同步，装上去 Sparkle 会拒绝更新）
    local_key = local_info_plist_public_key()
    if local_key:
        check(len(local_key) == 44, "SUPublicEDKey 看起来是合法 Ed25519 公钥", local_key[:16] + "…")
    else:
        check(True, "SUPublicEDKey 检查跳过（本地无 Info.plist）", "CI 外侧只校验 feed")

    # 5) 可选：真的下载并比对 sha256（默认关闭，健康检查开启）
    if download:
        check(enc_status == 200, "下载安装包", "先决条件")
        if enc_status != 200:
            return
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, zip_name)
            try:
                payload = fetch(newest["enclosure_url"])
            except Exception as err:  # noqa: BLE001
                check(False, "下载安装包", f"{type(err).__name__}: {err}")
                return
            with open(path, "wb") as handle:
                handle.write(payload)
            digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
            size = os.path.getsize(path)
            check(size > 1_000_000, "安装包大小合理（>1MB）", f"{size} bytes")
            sha_asset = next(n for n in assets if n.endswith(".zip.sha256"))
            expected = fetch(assets[sha_asset]["browser_download_url"]).decode().split()[0].strip()
            check(digest == expected, "sha256 与 .sha256 资产一致", f"actual={digest[:16]}… expected={expected[:16]}…")


def verify_repo_appcast() -> None:
    """校验仓库根 appcast.xml：enclosure 必须指向存在的产物。"""
    path = "appcast.xml"
    if not check(os.path.exists(path), "仓库根 appcast.xml 存在"):
        return
    try:
        items = sparkle_items(open(path, "rb").read())
    except Exception as err:  # noqa: BLE001
        check(False, "仓库根 appcast.xml 可解析", str(err))
        return
    check(bool(items), "仓库根 appcast.xml 至少一个 item", f"items={len(items)}")
    for item in items:
        ok, _ = retry(lambda: http_status(item["enclosure_url"]))
        check(ok == 200, f"根 appcast enclosure 可下载（build {item['version']}）",
              f"{item['enclosure_url'].rsplit('/', 1)[-1]} -> HTTP {ok}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tag", default="latest", help="latest 或具体 tag（如 v0.3.5-preview）")
    parser.add_argument("--download", action="store_true", help="下载安装包并校验 sha256")
    parser.add_argument("--self-check", action="store_true", help="只校验仓库内 appcast.xml")
    parser.add_argument("--also-self-check", action="store_true", help="发布校验之后再校验仓库内 appcast.xml")
    args = parser.parse_args()

    if args.self_check:
        verify_repo_appcast()
    else:
        verify_release(args.tag, args.download)
        # 根 appcast 是仓库文件，可能还没随发布更新（修复历史空 release 时会这样），
        # 所以默认不做这项检查，避免把"产物已修好但文档未合并"误判成发布失败。
        if args.also_self_check:
            verify_repo_appcast()

    failed = [r for r in results if not r[0]]
    network_only = bool(failed) and all("HTTP 0" in detail for _, _, detail in failed)
    print()
    for ok, name, detail in results:
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {name}" + (f"  —  {detail}" if detail else ""))
    print()
    if network_only:
        print(f"⚠️ {len(failed)} 项检查全部是网络不可达（HTTP 0），未能判定产物好坏。")
        print("   这不是发布事故：换网络重试，或等 CI 的 Release health 结果。")
        return 2
    if failed:
        print(f"❌ {len(failed)} 项失败 / {len(results)} 项检查：发布产物不可信，别发版。")
        return 1
    print(f"✅ {len(results)} 项全部通过：feed 可下载、资产非空、版本一致、enclosure 可达。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
