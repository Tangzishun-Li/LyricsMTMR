//
//  CitationGen.swift  ·  item type: citationGen
//  引用格式生成：读取剪贴板 DOI/URL，调用 CrossRef API 解析元数据，
//  生成 APA 7th / GB/T 7714-2015 格式引用，点击复制。
//  属性：style（APA / GB-T7714 / both）。
//

import Cocoa

class CitationGenItem: TBPopoverItem {
    private let style: String
    private weak var resultLabel: NSTextField?
    private var apaString = ""
    private var gbString = ""

    init(identifier: NSTouchBarItem.Identifier, style: String) {
        self.style = style
        super.init(identifier: identifier)
        configureButton(title: localized("引用", "Cite"), symbol: "quote.bubble", tint: TB.gold)
    }
    required init?(coder: NSCoder) { return nil }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.gold)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("读取剪贴板 DOI…", "reading clipboard DOI…"), tint: TB.textSecondary)

        let clip = TBClip.read().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let doi = Self.extractDOI(from: clip) else {
            resultLabel?.stringValue = localized("剪贴板无 DOI", "no DOI in clipboard")
            resultLabel?.textColor = TB.coral
            TBOverlay.buttonRow(in: card, buttons: [], afterClose: close)
            return root
        }

        resultLabel?.stringValue = localized("查询中…", "fetching…")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let (apa, gb) = Self.fetchCitation(doi: doi)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.apaString = apa
                self.gbString = gb
                var buttons: [NSButton] = []
                if self.style == "APA" || self.style == "both" {
                    let b = TBOverlay.pillButton(title: "APA", tag: 0, target: self, action: #selector(self.copyCitation(_:)), tint: TB.gold)
                    buttons.append(b)
                }
                if self.style == "GB-T7714" || self.style == "both" {
                    let b = TBOverlay.pillButton(title: "GB/T", tag: 1, target: self, action: #selector(self.copyCitation(_:)), tint: TB.mint)
                    buttons.append(b)
                }
                self.resultLabel?.stringValue = apa.isEmpty ? localized("查询失败", "fetch failed") : localized("点击复制格式", "tap to copy")
                self.resultLabel?.textColor = apa.isEmpty ? TB.coral : TB.textSecondary
                // Rebuild button row
                if let cardView = self.resultLabel?.superview {
                    for sub in cardView.subviews where sub is NSStackView { sub.removeFromSuperview() }
                    TBOverlay.buttonRow(in: cardView, buttons: buttons, afterClose: close)
                }
            }
        }

        TBOverlay.buttonRow(in: card, buttons: [], afterClose: close)
        return root
    }

    @objc private func copyCitation(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        let text = sender.tag == 0 ? apaString : gbString
        guard !text.isEmpty else { return }
        TBClip.write(text)
        resultLabel?.stringValue = localized("已复制 \(sender.tag == 0 ? "APA" : "GB/T") 格式", "copied")
        resultLabel?.textColor = TB.mint
    }

    // MARK: - DOI extraction

    private static func extractDOI(from text: String) -> String? {
        // Match DOI pattern: 10.xxxx/...
        if let range = text.range(of: ##"10\.\d{4,}/[^\s"#<>]+"##, options: .regularExpression) {
            var doi = String(text[range])
            // Trim trailing punctuation
            while let last = doi.last, ".,;)]}".contains(last) { doi.removeLast() }
            return doi
        }
        // Try extracting from URL like https://doi.org/10.xxxx/...
        if let range = text.range(of: ##"doi\.org/(10\.\d{4,}/[^\s"#<>]+)"##, options: .regularExpression) {
            let match = String(text[range])
            if let slashIdx = match.firstIndex(of: "/") {
                var doi = String(match[match.index(after: slashIdx)...])
                while let last = doi.last, ".,;)]}".contains(last) { doi.removeLast() }
                return doi
            }
        }
        return nil
    }

    // MARK: - CrossRef fetch + format

    private static func fetchCitation(doi: String) -> (apa: String, gb: String) {
        let encoded = doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? doi
        let url = "https://api.crossref.org/works/\(encoded)"
        guard let json = TBNet.json(url, headers: ["User-Agent": "LyricsMTMR/1.0 (mailto:touchbar@local)"]) as? [String: Any],
              let message = json["message"] as? [String: Any] else {
            return ("", "")
        }

        let title = (message["title"] as? [String])?.first ?? "Untitled"
        let authors = message["author"] as? [[String: Any]] ?? []
        let journal = (message["container-title"] as? [String])?.first ?? ""
        let volume = message["volume"] as? String ?? ""
        let page = message["page"] as? String ?? ""

        // Extract year
        var year = ""
        for key in ["published-print", "published-online", "issued", "created"] {
            if let dateObj = message[key] as? [String: Any],
               let parts = dateObj["date-parts"] as? [[Int]],
               let first = parts.first, let y = first.first {
                year = "\(y)"
                break
            }
        }

        // APA 7th: Author, A. A., & Author, B. (Year). Title. Journal, Volume, Pages.
        let apaAuthors = formatAuthorsAPA(authors)
        var apa = "\(apaAuthors) (\(year)). \(title)."
        if !journal.isEmpty { apa += " \(journal)" }
        if !volume.isEmpty { apa += ", \(volume)" }
        if !page.isEmpty { apa += ", \(page)" }
        apa += "."

        // GB/T 7714: 作者. 题名[J]. 刊名, 年, 卷: 页码.
        let gbAuthors = formatAuthorsGB(authors)
        var gb = "\(gbAuthors). \(title)[J]."
        if !journal.isEmpty { gb += " \(journal)" }
        if !year.isEmpty { gb += ", \(year)" }
        if !volume.isEmpty { gb += ", \(volume)" }
        if !page.isEmpty { gb += ": \(page)" }
        gb += "."

        return (apa, gb)
    }

    private static func formatAuthorsAPA(_ authors: [[String: Any]]) -> String {
        let names = authors.prefix(20).map { a -> String in
            let family = a["family"] as? String ?? ""
            let given = a["given"] as? String ?? ""
            let initials = given.split(separator: " ").compactMap { $0.first.map(String.init) }.joined(separator: ". ")
            return initials.isEmpty ? family : "\(family), \(initials)."
        }
        if names.isEmpty { return "Unknown" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return "\(names[0]), & \(names[1])" }
        return names.dropLast().joined(separator: ", ") + ", & " + names.last!
    }

    private static func formatAuthorsGB(_ authors: [[String: Any]]) -> String {
        let names = authors.prefix(3).map { a -> String in
            let family = a["family"] as? String ?? ""
            let given = a["given"] as? String ?? ""
            let initials = given.split(separator: " ").compactMap { $0.first.map(String.init) }.joined(separator: " ")
            return initials.isEmpty ? family : "\(family) \(initials)"
        }
        if names.isEmpty { return "佚名" }
        var result = names.joined(separator: ", ")
        if authors.count > 3 { result += ", 等" }
        return result
    }
}
