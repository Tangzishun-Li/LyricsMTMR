#!/usr/bin/env python3
"""Idempotently add .swift files to LyricsMTMR.xcodeproj/project.pbxproj.

Usage: python3 add_files.py Widgets:Foo.swift Preferences:Bar.swift Tools:Baz.swift ...
Each file gets 4 entries: PBXBuildFile, PBXFileReference, group child, Sources phase.
UUIDs are deterministic per-filename so re-runs are stable and idempotent.

Anchoring strategy (structural, round-16 fix — no hardcoded "last entry" anchors):
  - PBXBuildFile / PBXFileReference: appended at the END of their sections,
    right before the `/* End ... section */` markers;
  - group child: the target PBXGroup is located DYNAMICALLY by its `name`/`path`
    attribute (any group works: Widgets, Tools, Life, Preferences, ...) and the
    child is appended at the END of that group's children list;
  - Sources phase: resolved via the app target (LyricsMTMR) buildPhases, so new
    files always land in the APP's Sources phase (never the unit-test target's),
    appended at the END of the files list.
"""
import sys, re, hashlib, os

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "LyricsMTMR.xcodeproj", "project.pbxproj")

def uuids_for(name):
    h = hashlib.sha1(name.encode()).hexdigest().upper()
    ref = "C0FE" + h[:20]
    bld = "C0FF" + h[:20]
    return ref, bld

END_BUILDFILE = "/* End PBXBuildFile section */"
END_FILEREF = "/* End PBXFileReference section */"

def find_group_children_end(text, group):
    """Locate the PBXGroup whose name or path == group.

    Returns the text offset pointing right after the last child line
    (i.e. just before the closing '\\n\\t\\t\\t);' of the children list).
    """
    pat = re.compile(
        r'\t\t[0-9A-F]{24} /\* [^*]+? \*/ = \{\n'
        r'\t\t\tisa = PBXGroup;\n'
        r'(.*?)\n\t\t\};', re.DOTALL)
    candidates = []
    for m in pat.finditer(text):
        block = m.group(1)
        if re.search(r'\t\t\t(?:name|path) = ' + re.escape(group) + r';', block):
            candidates.append(m)
    if not candidates:
        raise SystemExit(f"group not found: {group}")
    if len(candidates) > 1:
        raise SystemExit(f"ambiguous group name/path: {group} ({len(candidates)} matches)")
    m = candidates[0]
    cm = re.search(r'\t\t\tchildren = \(\n(.*?)\n\t\t\t\);', m.group(1), re.DOTALL)
    if not cm:
        raise SystemExit(f"group {group}: children list not found")
    return m.start(1) + cm.end(1)

def find_app_sources_files_end(text):
    """Locate the app target's (LyricsMTMR) Sources phase files list.

    Returns the text offset right after the last files entry
    (just before the closing '\\n\\t\\t\\t);' of the files list).
    """
    tm = re.search(r'\t\t[0-9A-F]{24} /\* LyricsMTMR \*/ = \{\n(.*?)\n\t\t\};', text, re.DOTALL)
    if not tm:
        raise SystemExit("app target LyricsMTMR not found")
    bm = re.search(r'\t\t\tbuildPhases = \(\n(.*?)\n\t\t\t\);', tm.group(1), re.DOTALL)
    if not bm:
        raise SystemExit("app target buildPhases not found")
    pm = re.search(r'\t\t\t\t([0-9A-F]{24}) /\* Sources \*/', bm.group(1))
    if not pm:
        raise SystemExit("app target Sources phase not found")
    phase_id = pm.group(1)
    ph = re.search(r'\t\t' + phase_id + r' /\* Sources \*/ = \{\n(.*?)\n\t\t\};', text, re.DOTALL)
    if not ph:
        raise SystemExit(f"Sources phase {phase_id} block not found")
    fm = re.search(r'\t\t\tfiles = \(\n(.*?)\n\t\t\t\);', ph.group(1), re.DOTALL)
    if not fm:
        raise SystemExit("Sources phase files list not found")
    return ph.start(1) + fm.end(1)

def main():
    with open(PBX, "r") as f:
        text = f.read()

    build_lines, ref_lines = [], []
    group_children = {}  # group -> [child lines]
    sources_lines = []

    for arg in sys.argv[1:]:
        group, name = arg.split(":", 1)
        ref, bld = uuids_for(name)
        if ref in text:
            print(f"skip (present): {name}")
            continue
        build_lines.append(f"\t\t{bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n")
        ref_lines.append(f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n")
        sources_lines.append(f"\t\t\t\t{bld} /* {name} in Sources */,")
        group_children.setdefault(group, []).append(f"\t\t\t\t{ref} /* {name} */,")
        print(f"add: {group}/{name}")

    if not build_lines:
        print("nothing to do")
        return

    # 1) PBXBuildFile / PBXFileReference sections — append before End markers
    if END_BUILDFILE not in text or END_FILEREF not in text:
        raise SystemExit("pbxproj section end markers not found")
    text = text.replace(END_BUILDFILE, "".join(build_lines) + END_BUILDFILE, 1)
    text = text.replace(END_FILEREF, "".join(ref_lines) + END_FILEREF, 1)

    # 2) group children — append at the end of each located group's children list
    for group, children in group_children.items():
        pos = find_group_children_end(text, group)
        text = text[:pos] + "\n" + "\n".join(children) + text[pos:]

    # 3) Sources phase — append at the end of the app target's files list
    if sources_lines:
        pos = find_app_sources_files_end(text)
        text = text[:pos] + "\n" + "\n".join(sources_lines) + text[pos:]

    with open(PBX, "w") as f:
        f.write(text)
    print("done")

if __name__ == "__main__":
    main()
