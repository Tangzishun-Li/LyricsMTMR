//
//  DailyQuote.swift  ·  item type: dailyQuote
//  每日一言：调用 hitokoto 免费接口获取一句短句展示在 Touch Bar 上。无需 API Key。
//  收起态只显示短句预览；点按展开浮层查看完整句子与出处，
//  浮层内可「复制」整句或「换一句」重新拉取。
//  属性：refreshInterval。
//

import Cocoa

class DailyQuoteItem: TBMetricPopoverItem {
    private var quote = "…"
    private var source = ""
    /// Round 45: compute/refresh failure flips this; apply() and the
    /// popover refresh surface a coral failure visual instead of silently
    /// keeping a stale value.
    private var fetchFailed = false
    private weak var quoteLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double) {
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "quote.opening", tint: TB.purple,
                   label: localized("一言", "Quote"), width: 220)
        accent = TB.purple
    }
    required init?(coder: NSCoder) { return nil }

    override func compute() {
        fetchQuote()
    }

    private func fetchQuote() {
        guard let json = TBNet.json("https://v1.hitokoto.cn/?c=a&c=b&c=d&c=k") as? [String: Any],
              let text = json["hitokoto"] as? String else {
            fetchFailed = true
            quote = localized("离线：心有所向，方能行远", "offline quote")
            source = ""
            return
        }
        fetchFailed = false
        quote = text
        source = (json["from"] as? String) ?? ""
    }

    override func apply() {
        // 收起态只放短句预览，完整句子（含出处）留给浮层，避免挤成一团显示不下
        metric.value = quote
        metric.subValue = nil
        metric.valueColor = fetchFailed ? TB.coral : TB.textPrimary
        quoteLabel?.stringValue = overlayText()
        quoteLabel?.textColor = fetchFailed ? TB.coral : TB.textPrimary
    }

    private func overlayText() -> String {
        source.isEmpty ? quote : "\(quote) —— \(source)"
    }

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.purple)
        _ = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))

        // 完整句子允许折两行显示（11pt），按钮钉在卡片右缘，文字可用宽度最大化
        let label = NSTextField(labelWithString: overlayText())
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = TB.textPrimary
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 2
        label.cell?.wraps = true
        label.alignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        quoteLabel = label

        let copy = TBOverlay.pillButton(title: localized("复制", "Copy"), tag: 0, target: self, action: #selector(overlayAction(_:)), tint: TB.purple)
        let next = TBOverlay.pillButton(title: localized("换一句", "Next"), tag: 1, target: self, action: #selector(overlayAction(_:)), tint: TB.mint)
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 5
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        stack.addArrangedSubview(copy)
        stack.addArrangedSubview(next)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 36),
            label.trailingAnchor.constraint(lessThanOrEqualTo: stack.leadingAnchor, constant: -10),
        ])
        return root
    }

    @objc private func overlayAction(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .medium)
        if sender.tag == 0 {
            TBClip.write(overlayText())
            sender.title = localized("已复制 ✓", "copied ✓")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak sender] in
                sender?.title = localized("复制", "Copy")
            }
        } else {
            sender.isEnabled = false
            quoteLabel?.stringValue = localized("正在换一句…", "fetching…")
            quoteLabel?.textColor = TB.textPrimary
            DispatchQueue.global().async { [weak self] in
                self?.fetchQuote()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if self.fetchFailed {
                        // Round 45: failure must be visible — no silent stale-value keep.
                        self.quoteLabel?.stringValue = localized("获取失败，点击重试", "failed, tap to retry")
                        self.quoteLabel?.textColor = TB.coral
                    } else {
                        self.quoteLabel?.stringValue = self.overlayText()
                        self.quoteLabel?.textColor = TB.textPrimary
                    }
                    self.metric.value = self.quote
                    self.metric.valueColor = self.fetchFailed ? TB.coral : TB.textPrimary
                    self.metric.needsDisplay = true
                    sender.isEnabled = true
                }
            }
        }
    }
}
