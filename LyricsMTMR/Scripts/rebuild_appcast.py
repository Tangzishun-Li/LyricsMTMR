#!/usr/bin/env python3
"""用真实 release 产物重建仓库根 appcast.xml（原来是手写的，enclosure 指向不存在的 .dmg）。

只收录「该 release 真的附带 appcast.xml，且 enclosure 指向的资产真实存在」的条目，
所以根 appcast 从此是派生数据，不会再和 releases 漂移。

用法：
    python3 Scripts/rebuild_appcast.py            # 重写 appcast.xml
    python3 Scripts/rebuild_appcast.py --dry-run  # 只打印将要写入的内容
    python3 Scripts/rebuild_appcast.py --check-links  # 额外 HEAD 校验 enclosure（默认开启）

退出码：0 = 成功；1 = 无可用条目（此时不覆盖旧文件）。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

REPO = os.environ.get("LYRICSMTMR_REPO", "Tangzishun-Li/LyricsMTMR")
SPARKLE_NS = "http://www.andymatuschak.org/xml-namespaces/sparkle"
TOKEN = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")


def api(path: str):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{REPO}{path}",
        headers={"Accept": "application/vnd.github+json"},
    )
    if TOKEN:
        req.add_header("Authorization", f"Bearer {TOKEN}")
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def fetch(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "LyricsMTMR-appcast-rebuild"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        return resp.read()


def url_ok(url: str) -> bool:
    req = urllib.request.Request(url, headers={"User-Agent": "LyricsMTMR-appcast-rebuild"})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return resp.status == 200
    except urllib.error.HTTPError:
        return False


def collect() -> list[dict]:
    releases = api("/releases?per_page=100")
    entries: list[dict] = []
    for release in releases:
        if release.get("draft"):
            continue
        assets = {a["name"]: a for a in release.get("assets", [])}
        if "appcast.xml" not in assets:
            continue
        try:
            xml_bytes = fetch(assets["appcast.xml"]["browser_download_url"])
        except Exception as err:  # noqa: BLE001
            print(f"  ! {release['tag_name']}: 下载 appcast 失败：{err}", file=sys.stderr)
            continue
        root = ET.fromstring(xml_bytes)
        item = root.find(".//item")
        if item is None:
            continue
        enclosure = item.find("enclosure")
        if enclosure is None:
            continue
        enclosure_url = enclosure.get("url", "")
        asset_name = enclosure_url.rsplit("/", 1)[-1]
        if asset_name not in assets:
            print(f"  ! {release['tag_name']}: enclosure 指向不存在的资产 {asset_name}，跳过", file=sys.stderr)
            continue
        entries.append(
            {
                "tag": release["tag_name"],
                "title": item.findtext("title") or release["tag_name"],
                "pubDate": item.findtext("pubDate") or "",
                "version": int(item.findtext(f"{{{SPARKLE_NS}}}version") or 0),
                "shortVersion": item.findtext(f"{{{SPARKLE_NS}}}shortVersionString") or "",
                "enclosure_url": enclosure_url,
                "signature": enclosure.get(f"{{{SPARKLE_NS}}}edSignature", ""),
                "length": enclosure.get("length", ""),
            }
        )
    entries.sort(key=lambda e: e["version"], reverse=True)
    return entries


def render(entries: list[dict]) -> str:
    lines = [
        '<?xml version="1.0" standalone="no"?>',
        '<rss version="2.0"',
        '     xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"',
        '     xmlns:dc="http://purl.org/dc/elements/1.1/">',
        "  <channel>",
        "    <title>LyricsMTMR</title>",
        f"    <link>https://github.com/{REPO}</link>",
        "    <description>Most recent changes with links to updates.</description>",
        "    <language>zh</language>",
        "",
        "    <!-- 由 Scripts/rebuild_appcast.py 从真实 release 产物生成，请勿手改。 -->",
    ]
    for entry in entries:
        lines += [
            "    <item>",
            f"      <title>{entry['title']}</title>",
            f"      <sparkle:version>{entry['version']}</sparkle:version>",
            f"      <sparkle:shortVersionString>{entry['shortVersion']}</sparkle:shortVersionString>",
            "      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>",
            f"      <pubDate>{entry['pubDate']}</pubDate>",
            "      <enclosure",
            f'        url="{entry["enclosure_url"]}"',
            '        type="application/octet-stream"',
            f'        sparkle:edSignature="{entry["signature"]}"',
            f'        length="{entry["length"]}" />',
            "    </item>",
        ]
    lines += ["  </channel>", "</rss>", ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-check-links", action="store_true")
    parser.add_argument("--output", default="appcast.xml")
    args = parser.parse_args()

    entries = collect()
    print(f"收集到 {len(entries)} 个真实可更新条目：")
    for entry in entries:
        status = "ok" if args.no_check_links or url_ok(entry["enclosure_url"]) else "broken"
        print(f"  - build {entry['version']:>5}  {entry['shortVersion']:<16} {status}")
        if status == "broken":
            print(f"    ! {entry['enclosure_url']} 不可下载，剔除", file=sys.stderr)
    entries = [e for e in entries if args.no_check_links or url_ok(e["enclosure_url"])]

    if not entries:
        print("❌ 没有任何可用条目，保持原 appcast.xml 不变。", file=sys.stderr)
        return 1

    content = render(entries)
    if args.dry_run:
        print(content)
        return 0
    with open(args.output, "w", encoding="utf-8") as handle:
        handle.write(content)
    print(f"✅ 已写入 {args.output}（{len(entries)} 个条目）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
