#!/usr/bin/env python3
"""Idempotently add .swift files to LyricsMTMR.xcodeproj/project.pbxproj.

Usage: python3 add_files.py Widgets:Foo.swift Preferences:Bar.swift ...
Each file gets 4 entries: PBXBuildFile, PBXFileReference, group child, Sources phase.
UUIDs are deterministic per-filename so re-runs are stable and idempotent.
"""
import sys, re, hashlib, os

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "LyricsMTMR.xcodeproj", "project.pbxproj")

def uuids_for(name):
    h = hashlib.sha1(name.encode()).hexdigest().upper()
    ref = "C0FE" + h[:20]
    bld = "C0FF" + h[:20]
    return ref, bld

BUILD_ANCHOR = "\t\tB1C2D3E4F5A60718293A4C08 /* QuickReplyBarItem.swift in Sources */ = {isa = PBXBuildFile; fileRef = B1C2D3E4F5A60718293A4C07 /* QuickReplyBarItem.swift */; };\n"
REF_ANCHOR = "\t\tB1C2D3E4F5A60718293A4C07 /* QuickReplyBarItem.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = QuickReplyBarItem.swift; sourceTree = \"<group>\"; };\n"
SOURCES_ANCHOR = "\t\t\t\tB1C2D3E4F5A60718293A4C08 /* QuickReplyBarItem.swift in Sources */,"
WIDGETS_CHILD_ANCHOR = "\t\t\t\tB1C2D3E4F5A60718293A4C07 /* QuickReplyBarItem.swift */,"
PREFS_CHILD_ANCHOR = "\t\t\t\t2ECD9ADD4319B4536FB50594 /* UnifiedSettingsWindowController.swift */,"

def main():
    with open(PBX, "r") as f:
        text = f.read()

    build_lines, ref_lines, sources_lines = [], [], []
    widget_children, prefs_children = [], []

    for arg in sys.argv[1:]:
        group, name = arg.split(":", 1)
        ref, bld = uuids_for(name)
        if ref in text:
            print(f"skip (present): {name}")
            continue
        build_lines.append(f"\t\t{bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n")
        ref_lines.append(f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n")
        sources_lines.append(f"\t\t\t\t{bld} /* {name} in Sources */,")
        child = f"\t\t\t\t{ref} /* {name} */,"
        if group == "Widgets":
            widget_children.append(child)
        elif group == "Preferences":
            prefs_children.append(child)
        else:
            raise SystemExit(f"unknown group {group}")
        print(f"add: {group}/{name}")

    if not (build_lines or ref_lines):
        print("nothing to do")
        return

    text = text.replace(BUILD_ANCHOR, BUILD_ANCHOR + "".join(build_lines), 1)
    text = text.replace(REF_ANCHOR, REF_ANCHOR + "".join(ref_lines), 1)
    if sources_lines:
        pat = re.escape(SOURCES_ANCHOR) + r"\);"
        repl = SOURCES_ANCHOR + "\n" + "\n".join(sources_lines) + "\n\t\t\t);"
        text = re.sub(pat, lambda m: repl, text, count=1)
    if widget_children:
        pat = re.escape(WIDGETS_CHILD_ANCHOR) + r"\);"
        repl = WIDGETS_CHILD_ANCHOR + "\n" + "\n".join(widget_children) + "\n\t\t\t);"
        text = re.sub(pat, lambda m: repl, text, count=1)
    if prefs_children:
        text = text.replace(PREFS_CHILD_ANCHOR, PREFS_CHILD_ANCHOR + "\n" + "\n".join(prefs_children), 1)

    with open(PBX, "w") as f:
        f.write(text)
    print("done")

if __name__ == "__main__":
    main()
