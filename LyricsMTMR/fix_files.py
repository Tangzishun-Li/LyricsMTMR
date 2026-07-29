#!/usr/bin/env python3
"""Fix: insert widget files into Widgets group children + Sources build phase.
The PBXBuildFile/PBXFileReference entries were already added by add_files.py;
this adds the two missing list memberships that its regex skipped.
Idempotent: skips files already present in each list.
"""
import sys, hashlib, os

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "LyricsMTMR.xcodeproj", "project.pbxproj")

def uuids_for(name):
    h = hashlib.sha1(name.encode()).hexdigest().upper()
    return "C0FE" + h[:20], "C0FF" + h[:20]

SOURCES_ANCHOR = "\t\t\t\tB1C2D3E4F5A60718293A4C08 /* QuickReplyBarItem.swift in Sources */,"
WIDGETS_CHILD_ANCHOR = "\t\t\t\tB1C2D3E4F5A60718293A4C07 /* QuickReplyBarItem.swift */,"

def main():
    with open(PBX) as f:
        text = f.read()

    sources_add, children_add = [], []
    for arg in sys.argv[1:]:
        group, name = arg.split(":", 1)
        if group != "Widgets":
            raise SystemExit("only Widgets supported")
        ref, bld = uuids_for(name)
        src_line = f"\t\t\t\t{bld} /* {name} in Sources */,"
        child_line = f"\t\t\t\t{ref} /* {name} */,"
        if src_line not in text:
            sources_add.append(src_line)
        if child_line not in text:
            children_add.append(child_line)

    if sources_add:
        assert SOURCES_ANCHOR in text, "sources anchor missing"
        text = text.replace(SOURCES_ANCHOR, SOURCES_ANCHOR + "\n" + "\n".join(sources_add), 1)
    if children_add:
        assert WIDGETS_CHILD_ANCHOR in text, "widgets child anchor missing"
        text = text.replace(WIDGETS_CHILD_ANCHOR, WIDGETS_CHILD_ANCHOR + "\n" + "\n".join(children_add), 1)

    with open(PBX, "w") as f:
        f.write(text)
    print(f"added {len(sources_add)} sources entries, {len(children_add)} group children")

if __name__ == "__main__":
    main()
