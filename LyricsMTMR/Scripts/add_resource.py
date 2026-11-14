#!/usr/bin/env python3
"""把非源码文件（许可/声明等）注册进 App target 的 Resources 构建阶段。

用法（路径相对于 LyricsMTMR/ 工程目录）：
    python3 Scripts/add_resource.py ../LICENSE ../THIRD_PARTY_NOTICES.md ../LICENSES/MPL-2.0.txt

设计：
  - UUID 由路径 md5 派生，重复执行结果稳定；已注册的路径直接跳过（幂等）。
  - 文件引用挂在工程根 PBXGroup 下，sourceTree = "<group>"，因此 `../` 可指向仓库根。
  - 任何查找失败都在写盘前抛错，不会留下半注册状态。
"""
import hashlib
import os
import re
import sys

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "LyricsMTMR.xcodeproj", "project.pbxproj")
RESOURCES_PHASE = "B082B24D205C7D8000BC04DC"  # LyricsMTMR target 的 Resources phase
ROOT_GROUP = "B082B246205C7D8000BC04DC"  # 工程根 group
PROJECT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def uuid_for(path: str, kind: str) -> str:
    return hashlib.md5(f"{kind}:{path}".encode()).hexdigest().upper()[:24]


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    text = open(PBX, encoding="utf-8").read()

    for rel in argv:
        abs_path = os.path.normpath(os.path.join(PROJECT_DIR, rel))
        if not os.path.exists(abs_path):
            raise SystemExit(f"文件不存在：{rel} -> {abs_path}")
        if f'path = {rel};' in text:
            print(f"跳过（已注册）：{rel}")
            continue

        ref_uuid = uuid_for(rel, "ref")
        build_uuid = uuid_for(rel, "build")
        name = os.path.basename(rel)
        file_type = "net.daringfireball.markdown" if name.endswith(".md") else "text"

        build_entry = (
            f"\t\t{build_uuid} /* {name} in Resources */ = "
            f"{{isa = PBXBuildFile; fileRef = {ref_uuid} /* {name} */; }};\n"
        )
        ref_entry = (
            f"\t\t{ref_uuid} /* {name} */ = {{isa = PBXFileReference; "
            f"lastKnownFileType = {file_type}; name = {name}; path = {rel}; sourceTree = \"<group>\"; }};\n"
        )
        if "/* End PBXBuildFile section */" not in text or "/* End PBXFileReference section */" not in text:
            raise SystemExit("pbxproj 结构异常：找不到 build file / file reference 段结束标记")
        text = text.replace("/* End PBXBuildFile section */", build_entry + "/* End PBXBuildFile section */", 1)
        text = text.replace("/* End PBXFileReference section */", ref_entry + "/* End PBXFileReference section */", 1)

        # 根 group 的 children：在该 block 的 ");" 前插入
        group_pattern = re.compile(rf"(\t\t{ROOT_GROUP} = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \(\n)(.*?)(\t\t\t\);\n)", re.S)
        match = group_pattern.search(text)
        if not match:
            raise SystemExit("pbxproj 结构异常：找不到根 PBXGroup")
        text = text[: match.start(3)] + f"\t\t\t\t{ref_uuid} /* {name} */,\n" + text[match.start(3):]

        # Resources 构建阶段：在 files = ( ... ); 的 ");" 前插入
        phase_pattern = re.compile(rf"(\t\t{RESOURCES_PHASE} /\* Resources \*/ = \{{\n\t\t\tisa = PBXResourcesBuildPhase;\n.*?files = \(\n)(.*?)(\t\t\t\);\n)", re.S)
        match = phase_pattern.search(text)
        if not match:
            raise SystemExit("pbxproj 结构异常：找不到 Resources 构建阶段")
        text = text[: match.start(3)] + f"\t\t\t\t{build_uuid} /* {name} in Resources */,\n" + text[match.start(3):]

        print(f"已注册资源：{rel}")

    open(PBX, "w", encoding="utf-8").write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
