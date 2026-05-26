import plistlib, uuid

with open("LyricsMTMR.xcodeproj/project.pbxproj", "rb") as f:
    data = plistlib.load(f)

objects = data["objects"]

fid = uuid.uuid4().hex[:24].upper()
bid = uuid.uuid4().hex[:24].upper()

objects[fid] = {"isa": "PBXFileReference", "lastKnownFileType": "sourcecode.swift",
                "path": "WebSettingsController.swift", "sourceTree": "<group>"}
objects[bid] = {"isa": "PBXBuildFile", "fileRef": fid}

for oid, obj in objects.items():
    if isinstance(obj, dict) and obj.get("isa") == "PBXGroup" and obj.get("path") == "Preferences":
        obj["children"].append(fid)
        break

for oid, obj in objects.items():
    if isinstance(obj, dict) and obj.get("isa") == "PBXSourcesBuildPhase":
        obj["files"].append(bid)

with open("LyricsMTMR.xcodeproj/project.pbxproj", "wb") as f:
    plistlib.dump(data, f)

print("Added WebSettingsController.swift")
