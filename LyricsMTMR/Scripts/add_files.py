#!/usr/bin/env python3
"""Idempotently add .swift files to LyricsMTMR.xcodeproj/project.pbxproj.

Usage:
  python3 add_files.py Widgets:Foo.swift Preferences:Bar.swift Tools:Baz.swift ...
  python3 add_files.py Tests:FooTests.swift                          # test files

Each file gets 4 entries: PBXBuildFile, PBXFileReference, group child, Sources phase.
UUIDs are deterministic per-filename so re-runs are stable and idempotent.

Two registration modes:
  - App files (<Group>:<Name>.swift): group child lands in the PBXGroup located by
    name/path == <Group> (Widgets, Tools, Life, ...), Sources entry lands in the APP
    target's (LyricsMTMR) Sources phase.
  - Test files (Tests:<Name>.swift): group child lands in the MTMRTests PBXGroup,
    Sources entry lands in the UNIT-TEST target's (LyricsMTMRTests) Sources phase
    — never the app target's. UUIDs use the dedicated C1FE/C1FF prefix (app files
    keep C0FE/C0FF), so an app file and a test file can never collide and the two
    registration families stay distinguishable.

Anchoring strategy (structural, round-16 fix — no hardcoded "last entry" anchors):
  - PBXBuildFile / PBXFileReference: appended at the END of their sections,
    right before the `/* End ... section */` markers;
  - group child: the target PBXGroup is located DYNAMICALLY by its `name`/`path`
    attribute and the child is appended at the END of that group's children list;
  - Sources phase: resolved via the target's (app: LyricsMTMR, test: LyricsMTMRTests)
    buildPhases, appended at the END of the files list.

Failure mode: every lookup failure raises SystemExit BEFORE anything is written to
disk, so a broken invocation never leaves a half-registered pbxproj (round-16 style).
"""
import sys, re, hashlib, os

PBX = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "LyricsMTMR.xcodeproj", "project.pbxproj")

APP_TARGET = "LyricsMTMR"
TEST_TARGET = "LyricsMTMRTests"
TEST_GROUP = "MTMRTests"
TEST_ARG_PREFIX = "Tests"

def uuids_for(name, test=False):
    h = hashlib.sha1(name.encode()).hexdigest().upper()
    if test:
        return "C1FE" + h[:20], "C1FF" + h[:20]
    return "C0FE" + h[:20], "C0FF" + h[:20]

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

def find_target_sources_files_end(text, target):
    """Locate the given target's Sources phase files list.

    Returns the text offset right after the last files entry
    (just before the closing '\\n\\t\\t\\t);' of the files list).
    """
    tm = re.search(r'\t\t[0-9A-F]{24} /\* ' + re.escape(target) + r' \*/ = \{\n(.*?)\n\t\t\};', text, re.DOTALL)
    if not tm:
        raise SystemExit(f"target {target} not found")
    bm = re.search(r'\t\t\tbuildPhases = \(\n(.*?)\n\t\t\t\);', tm.group(1), re.DOTALL)
    if not bm:
        raise SystemExit(f"target {target}: buildPhases not found")
    pm = re.search(r'\t\t\t\t([0-9A-F]{24}) /\* Sources \*/', bm.group(1))
    if not pm:
        raise SystemExit(f"target {target}: Sources phase not found")
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
    app_sources_lines = []
    test_sources_lines = []

    for arg in sys.argv[1:]:
        group, name = arg.split(":", 1)
        is_test = (group == TEST_ARG_PREFIX)
        target_group = TEST_GROUP if is_test else group
        ref, bld = uuids_for(name, test=is_test)
        if ref in text:
            print(f"skip (present): {name}")
            continue
        build_lines.append(f"\t\t{bld} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {name} */; }};\n")
        ref_lines.append(f"\t\t{ref} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};\n")
        (test_sources_lines if is_test else app_sources_lines).append(f"\t\t\t\t{bld} /* {name} in Sources */,")
        group_children.setdefault(target_group, []).append(f"\t\t\t\t{ref} /* {name} */,")
        mode = "Tests" if is_test else group
        print(f"add: {mode}/{name}")

    if not build_lines:
        print("nothing to do")
        return

    # Phase 1 — validate everything against the ORIGINAL text (no writes yet).
    if END_BUILDFILE not in text or END_FILEREF not in text:
        raise SystemExit("pbxproj section end markers not found")
    edits = []
    edits.append((text.index(END_BUILDFILE), "".join(build_lines)))
    edits.append((text.index(END_FILEREF), "".join(ref_lines)))
    for group, children in group_children.items():
        pos = find_group_children_end(text, group)
        edits.append((pos, "\n" + "\n".join(children)))
    if app_sources_lines:
        pos = find_target_sources_files_end(text, APP_TARGET)
        edits.append((pos, "\n" + "\n".join(app_sources_lines)))
    if test_sources_lines:
        pos = find_target_sources_files_end(text, TEST_TARGET)
        edits.append((pos, "\n" + "\n".join(test_sources_lines)))

    # Phase 2 — apply edits from the END of the file backwards so earlier
    # offsets stay valid, then write once.
    for pos, insertion in sorted(edits, key=lambda e: e[0], reverse=True):
        text = text[:pos] + insertion + text[pos:]

    with open(PBX, "w") as f:
        f.write(text)
    print("done")

if __name__ == "__main__":
    main()
