//
//  AppleScriptGenerator.swift
//  LyricsMTMR
//
//  Generates and parses AppleScript key-combination strings used by
//  Touch Bar items. Also handles API-call script generation.
//

import Foundation

enum AppleScriptGenerator {

    // MARK: - Key combo → AppleScript

    /// Generate: `tell application "System Events" to key code 0 using {command down}`
    static func generateKeyPress(keyCode: UInt16, modifiers: Set<KeyModifier>) -> String {
        if modifiers.isEmpty {
            return "tell application \"System Events\" to key code \(keyCode)"
        }
        let modStr = KeyCodeMap.appleScriptModifiers(modifiers)
        return "tell application \"System Events\" to key code \(keyCode) using {\(modStr)}"
    }

    /// Generate a multi-step script: activate app, then send key combo
    static func generateAppKeyPress(appName: String, keyCode: UInt16, modifiers: Set<KeyModifier>) -> String {
        var lines: [String] = []
        lines.append("activate application \"\(appName)\"")
        lines.append("tell application \"System Events\"")
        if modifiers.isEmpty {
            lines.append("\tkey code \(keyCode)")
        } else {
            let modStr = KeyCodeMap.appleScriptModifiers(modifiers)
            lines.append("\tkey code \(keyCode) using {\(modStr)}")
        }
        lines.append("end tell")
        return lines.joined(separator: "\n")
    }

    // MARK: - Parse AppleScript → key combo

    struct ParsedKeyCombo {
        let keyCode: UInt16
        let modifiers: Set<KeyModifier>
    }

    /// Parse `key code 123 using {control down}` patterns from an inline script.
    /// Returns nil if the script doesn't contain a recognizable key code pattern.
    static func parseKeyCombo(from script: String) -> ParsedKeyCombo? {
        // Match: key code <number> [using {<modifiers>}]
        let pattern = #"key code (\d+)(?:\s+using\s*\{([^}]*)\})?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: script, range: NSRange(script.startIndex..., in: script))
        else { return nil }

        guard let codeRange = Range(match.range(at: 1), in: script),
              let code = UInt16(script[codeRange])
        else { return nil }

        var modifiers = Set<KeyModifier>()
        if match.range(at: 2).location != NSNotFound,
           let modRange = Range(match.range(at: 2), in: script) {
            let modStr = String(script[modRange])
            for mod in KeyModifier.allCases {
                if modStr.contains(mod.rawValue) {
                    modifiers.insert(mod)
                }
            }
        }

        return ParsedKeyCombo(keyCode: code, modifiers: modifiers)
    }

    /// Scan an items array and extract all key bindings found in actionAppleScript fields.
    static func extractBindings(from items: [[String: Any]]) -> [(index: Int, title: String, combo: ParsedKeyCombo)] {
        var results: [(index: Int, title: String, combo: ParsedKeyCombo)] = []
        scanItems(items, path: [], results: &results)
        return results
    }

    private static func scanItems(_ items: [[String: Any]], path: [Int],
                                  results: inout [(index: Int, title: String, combo: ParsedKeyCombo)]) {
        for (i, item) in items.enumerated() {
            let title = item["title"] as? String ?? ""
            // Check actionAppleScript.inline
            if let actionScript = item["actionAppleScript"] as? [String: Any],
               let inline = actionScript["inline"] as? String,
               let combo = parseKeyCombo(from: inline) {
                let flatIndex = path.isEmpty ? i : path[0]
                results.append((index: flatIndex, title: title, combo: combo))
            }
            // Recurse into child items
            if let children = item["items"] as? [[String: Any]] {
                scanItems(children, path: path + [i], results: &results)
            }
        }
    }

    // MARK: - API call script generation

    /// Generate an AppleScript that calls an HTTP API and returns a value.
    /// Used by `appleScriptTitledButton` items with `source.inline`.
    static func generateAPIScript(url: String, method: String = "GET",
                                  headers: [String: String] = [:],
                                  jqPath: String? = nil) -> String {
        var curlParts = ["curl", "-s", "-X", method]
        for (key, value) in headers {
            curlParts.append("-H")
            curlParts.append("'\(key): \(value)'")
        }
        curlParts.append("'\(url)'")

        var pipeline = curlParts.joined(separator: " ")
        if let jq = jqPath, !jq.isEmpty {
            pipeline += " | jq -r '\(jq)'"
        }

        return """
        set apiResult to do shell script "\(pipeline)"
        return apiResult
        """
    }

    /// Generate a script that activates an app and performs UI scripting
    static func generateUIScript(appName: String, processScript: String) -> String {
        return """
        activate application "\(appName)"
        tell application "System Events"
        \ttell process "\(appName)"
        \(processScript.split(separator: "\n").map { "\t\t" + $0 }.joined(separator: "\n"))
        \tend tell
        end tell
        """
    }
}
