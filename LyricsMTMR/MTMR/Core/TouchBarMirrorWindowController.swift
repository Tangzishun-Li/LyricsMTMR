import Cocoa

class TouchBarMirrorWindowController: NSObject {
    static let shared = TouchBarMirrorWindowController()

    private var window: NSPanel?
    private var stackView: NSStackView?
    private var syncTimer: Timer?

    /// item 内容指纹缓存：指纹未变化的 item 视图原地保留（增量同步，OPT-17）
    private var itemFingerprints: [NSTouchBarItem.Identifier: ItemFingerprint] = [:]

    /// ITER-3: 快照类 item 节流。快照类（AppScrubber/音量/亮度/自定义视图）没有低成本
    /// 指纹，旧逻辑每 0.1s tick 都重截一次位图；它们的内容变化频率远低于 10Hz，
    /// 因此只允许每隔若干 tick（ITER-9 按快照 item 数量自适应，见下）重建一次。
    /// ITER-11: syncTick 在 show() 时归零，使快照相位在每次显示后可预期。
    private var syncTick: Int = 0

    /// ITER-15: 指纹类 item 的内容脏标记。由 CustomButtonTouchBarItem 的
    /// attributedTitle/image didSet 经 noteContentDirty(identifier:) 置位——指纹类内容
    /// 变化不再依赖轮询兜底，而是事件驱动；心跳 tick 只在「脏 或 快照节流到期」时才做同步。
    /// 线程安全：didSet 可能来自任意队列（如网络回调），全部经 contentDirtyLock 保护。
    private let contentDirtyLock = NSLock()
    private var _contentDirtyIdentifiers: Set<NSTouchBarItem.Identifier> = []
    /// 是否已有一个合并同步在主队列排队（防高频内容风暴重复排队，coalesce 核心）。
    private var _coalesceScheduled = false

    /// ITER-15: 当前是否存在未消费的内容脏位。
    /// `internal` (was `private`) so MTMRTests can assert the dirty-flag lifecycle
    /// via `@testable import` (ITER-15); no logic change.
    var contentDirty: Bool {
        contentDirtyLock.lock()
        defer { contentDirtyLock.unlock() }
        return !_contentDirtyIdentifiers.isEmpty
    }

    /// ITER-15: 当前是否有合并同步排队中（测试观察面，恒等 _coalesceScheduled）。
    var isCoalesceScheduledForTesting: Bool {
        contentDirtyLock.lock()
        defer { contentDirtyLock.unlock() }
        return _coalesceScheduled
    }

    /// ITER-15: 内容变更事件入口（线程安全、幂等合并）。任意线程/任意次数调用都只是置脏；
    /// 仅当没有排队中的合并同步时才向主队列排一个 —— 同一轮高频内容风暴（N 次置脏）
    /// 只触发一次实际 syncFromTouchBar()，防抖不放大。主队列块先取走并清空脏位再同步，
    /// 同步期间新到的置脏会重新排队下一跳（不丢事件）。
    func noteContentDirty(identifier: NSTouchBarItem.Identifier) {
        contentDirtyLock.lock()
        _contentDirtyIdentifiers.insert(identifier)
        let shouldSchedule = !_coalesceScheduled
        _coalesceScheduled = true
        contentDirtyLock.unlock()
        guard shouldSchedule else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 取走脏位并解除排队标记；期间新置的脏由后续调用自行排队
            self.contentDirtyLock.lock()
            let ids = self._contentDirtyIdentifiers
            self._contentDirtyIdentifiers.removeAll()
            self._coalesceScheduled = false
            self.contentDirtyLock.unlock()
            guard !ids.isEmpty else { return }  // 脏位已被心跳先行消费 → 零工作返回
            self.syncFromTouchBar()
        }
    }

    /// ITER-9: 快照节流间隔按当前布局中快照类 item 数量自适应 —— 快照越多，
    /// 每 tick 全量重截位图越贵，间隔越长：
    /// 0-1 个 → 5 tick（0.5s，原值）；2 个 → 7 tick（0.7s，中间值）；≥3 个 → 10 tick（1s）。
    private static func snapshotRefreshInterval(forSnapshotCount count: Int) -> Int {
        switch count {
        case 0...1: return 5
        case 2: return 7
        default: return 10
        }
    }

    private var isVisible: Bool = false {
        didSet { AppSettings.showMirrorWindow = isVisible }
    }

    private override init() {
        super.init()
        if AppSettings.showMirrorWindow {
            DispatchQueue.main.async { [weak self] in self?.show() }
        }
    }

    func show() {
        // ITER-11: 快照相位归零 —— 每次显示后节流节奏重新从第 1 个 tick 起算，
        // 快照刷新时刻可预期（间隔固定时始终是「显示后第 N 个 tick」）。
        syncTick = 0
        if window != nil {
            window?.orderFront(nil)
            isVisible = true
            startSyncTimer()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 34),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hasShadow = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false

        let bg = TouchBarBackgroundView(frame: panel.contentView!.bounds)
        bg.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(bg)

        let sv = NSStackView()
        sv.spacing = 8
        sv.orientation = .horizontal
        sv.alignment = .centerY
        sv.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(sv)

        NSLayoutConstraint.activate([
            sv.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            sv.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            sv.leadingAnchor.constraint(greaterThanOrEqualTo: bg.leadingAnchor, constant: 8),
            sv.trailingAnchor.constraint(lessThanOrEqualTo: bg.trailingAnchor, constant: -8),
        ])

        stackView = sv

        window = panel
        positionAtBottomCenter()
        panel.orderFront(nil)
        isVisible = true

        syncFromTouchBar()
        startSyncTimer()
    }

    func hide() {
        syncTimer?.invalidate()
        syncTimer = nil
        window?.orderOut(nil)
        isVisible = false
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    /// ITER-15: 0.1s 兜底轮询 → 1s 脏检查心跳。
    /// 演进缘由：增量指纹比对（OPT-17）落地后绝大多数 tick 本就零重建，10Hz 主线程
    /// 唤醒只剩兜底价值却仍是常驻开销；事件源其实早已存在——TouchBarController 在
    /// 布局重建/activeApp 变化时主动调 syncFromTouchBar()（TouchBarController.swift
    /// :567/:926），ITER-15 再把「item 内容变化」也事件化（CustomButtonTouchBarItem
    /// didSet → noteContentDirty）。于是轮询降级为 1s 心跳，仅当「指纹类内容脏 或
    /// 快照类节流到期」才真正同步，否则零工作返回：
    ///   - 快照类 item 存在时沿用 ITER-9 自适应间隔语义，换算见 snapshotDueTickLimit；
    ///   - 纯指纹类布局空闲心跳成本 ≈ 一次 Set 查询；
    ///   - 布局级事件路径（:567/:926 → isHeartbeat=false）保持即时同步不变。
    private func startSyncTimer() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.syncFromTouchBar(isHeartbeat: true)
        }
    }

    private func positionAtBottomCenter() {
        guard let window = window, let screen = NSScreen.main else { return }
        let sf = screen.frame
        let w = min(sf.width * 0.76, 1065)
        let x = sf.origin.x + (sf.width - w) / 2
        let y = sf.origin.y + 4
        window.setFrame(NSRect(x: x, y: y, width: w, height: 34), display: true)
    }

    /// 增量同步（OPT-17）：与 Touch Bar 当前布局做结构对齐，仅重建内容变化的 item 视图，
    /// 未变化的视图与分隔线原地保留 —— 取代原先每 0.1s 全量清空 stackView 并重建全部 item NSView。
    /// 布局增删/换序时 TouchBarController 已事件驱动调用本方法，无需依赖高频轮询。
    ///
    /// ITER-15: isHeartbeat 区分两类入口：
    ///   - true（1s 心跳）：仅当「指纹类内容脏 或 快照节流到期」才执行同步，
    ///     否则零工作返回（不触 TouchBarController.shared 单例初始化）；
    ///   - false（默认；noteContentDirty 合并路径 + :567/:926 布局事件）：即时同步不变。
    func syncFromTouchBar(isHeartbeat: Bool = false) {
        // ITER-15: 心跳门控。纯指纹布局且无脏位 → 本 tick 零工作。
        // 门控判定不触碰 TouchBarController.shared：无窗口上下文（含单测）零副作用；
        if isHeartbeat {
            guard contentDirty || Self.layoutHasSnapshotItems() else { return }
        }

        // ITER-15: 消费当前脏位——本次调用即被视为「已负责反映最新内容」
        // （布局事件路径的全量同步经指纹比对天然覆盖内容变化；无窗口时无可反射面，
        // 下一次内容变更会重新置脏）。消费先行于 stackView 守卫：置脏后窗口关闭
        // 的场景也不残留陈旧脏位。
        contentDirtyLock.lock()
        _contentDirtyIdentifiers.removeAll()
        contentDirtyLock.unlock()

        let controller = TouchBarController.shared
        guard let sv = stackView else { return }

        syncTick += 1

        let leftItems = controller.leftIdentifiers.compactMap { controller.items[$0] }
        let centerItems = controller.centerIdentifiers.compactMap { controller.items[$0] }
        let rightItems = controller.rightIdentifiers.compactMap { controller.items[$0] }

        // ITER-9: 每 tick 按当前布局中快照类 item 数（fingerprint 为 nil，即
        // AppScrubber/音量/亮度/自定义视图等无低成本指纹的 item）求自适应节流间隔；
        // 数量变化后下一 tick 自动切换间隔。
        let snapshotCount = (leftItems + centerItems + rightItems)
            .filter { fingerprint(of: $0) == nil }.count
        // ITER-3: 只有到了降频刷新点，快照类 item 才允许重建（重截位图）
        // ITER-15: 心跳 10× 变慢后按时间重标定——旧间隔 N 个 0.1s tick = N×0.1 秒，
        // 每秒至多 1 个心跳 → 到期上限 max(1, round(N×0.1)) 个心跳（5/7/10 tick
        // ≈ 0.5/0.7/1.0s → 全部 ≤1 心跳），快照刷新延迟不劣于 ITER-9 原值。
        let snapshotDueTickLimit = Self.snapshotDueHeartbeats(forLegacyTicks: Self.snapshotRefreshInterval(forSnapshotCount: snapshotCount))
        let snapshotDue = syncTick % snapshotDueTickLimit == 0

        // 目标布局：与全量重建一致的 (item | separator) 序列
        var targets: [MirrorElement] = []
        var first = true
        for items in [leftItems, centerItems, rightItems] {
            if items.isEmpty { continue }
            if !first { targets.append(.separator) }
            first = false
            targets.append(contentsOf: items.map { .item($0) })
        }

        var current = sv.arrangedSubviews
        var liveIdentifiers = Set<NSTouchBarItem.Identifier>()

        // 按位置对齐：类型不匹配 → 换视图；同 item 且指纹未变 → 原地保留；指纹变化 → 只重建该单个视图
        for (index, target) in targets.enumerated() {
            if index < current.count {
                let existing = current[index]
                if view(existing, matches: target) {
                    if case let .item(item) = target {
                        liveIdentifiers.insert(item.identifier)
                        if let fingerprint = fingerprint(of: item) {
                            if itemFingerprints[item.identifier] == fingerprint { continue }  // 内容未变
                            // 指纹变化 → 只重建该单个视图；makeView 会带上 identifier，
                            // 保证下一轮同步仍能命中 matches（避免无标识视图再被 else 分支重建一次）
                            let newView = makeView(for: .item(item))
                            replace(existing, with: newView, in: sv, at: index)
                            current[index] = newView
                            itemFingerprints[item.identifier] = fingerprint
                        } else {
                            // 快照类（AppScrubber/音量/亮度/自定义视图）：无低成本指纹。
                            // FIX-1 语义保留：快照必须能刷新，绝不永久冻结 —— 只是降频。
                            // ITER-3 + ITER-9：按当前快照 item 数量自适应间隔
                            // （1 个 ≈0.5s，2 个 ≈0.7s，3 个以上 ≈1s）才重建一次；
                            // 未到刷新点时原地保留上一帧快照。
                            if !snapshotDue { continue }
                            itemFingerprints.removeValue(forKey: item.identifier)
                            let newView = makeView(for: .item(item))
                            replace(existing, with: newView, in: sv, at: index)
                            current[index] = newView
                        }
                    }
                } else {
                    let newView = makeView(for: target)
                    replace(existing, with: newView, in: sv, at: index)
                    current[index] = newView
                    remember(newView, for: target, identifiers: &liveIdentifiers)
                }
            } else {
                let newView = makeView(for: target)
                sv.addArrangedSubview(newView)
                current.append(newView)
                remember(newView, for: target, identifiers: &liveIdentifiers)
            }
        }

        // 移除尾部多余视图（item 被移除/布局收窄）
        while current.count > targets.count {
            let extra = current.removeLast()
            sv.removeArrangedSubview(extra)
            extra.removeFromSuperview()
        }

        // 清理已不在布局中的指纹缓存
        itemFingerprints = itemFingerprints.filter { liveIdentifiers.contains($0.key) }
    }

    // MARK: - 增量同步辅助（OPT-17）

    /// ITER-15: 心跳周期（秒）。旧兜底轮询 0.1s 的 10 倍。
    static let heartbeatSeconds: Double = 1.0

    /// ITER-15: ITER-9 自适应间隔（旧 0.1s tick 计数 N）换算为心跳到期上限。
    /// 时间等价：N 个 0.1s tick = N×0.1s；心跳粒度 1s → max(1, round(N×0.1))。
    /// 现行值域 5/7/10 tick ≈ 0.5/0.7/1.0s → 全部折算为 1 心跳，快照刷新延迟
    /// 不劣于 ITER-9 原值；若未来间隔显著加长，公式自动按秒放大。
    /// `static internal` so MTMRTests can pin the rescale semantics (ITER-15).
    static func snapshotDueHeartbeats(forLegacyTicks legacyTicks: Int) -> Int {
        return max(1, Int((Double(legacyTicks) * legacyTickSeconds / heartbeatSeconds).rounded()))
    }

    /// ITER-15: 旧轮询 tick 周期（秒）——ITER-9 间隔的时间基准。
    private static let legacyTickSeconds: Double = 0.1

    /// ITER-15: 当前布局是否含快照类 item（无低成本指纹者）。
    /// 只读 controller.items 字典与 identifier 数组——刻意不触发视图构建；
    /// `static internal` so MTMRTests can drive the heartbeat gate (ITER-15).
    static func layoutHasSnapshotItems() -> Bool {
        let controller = TouchBarController.shared
        for ids in [controller.leftIdentifiers, controller.centerIdentifiers, controller.rightIdentifiers] {
            if ids.contains(where: { controller.items[$0] != nil }) {
                // 该分区有 item；再确认其中是否存在快照类（fingerprint 为 nil）
                for id in ids where controller.items[id] != nil {
                    if Self.instanceFingerprint(of: controller.items[id]!) == nil { return true }
                }
            }
        }
        return false
    }

    /// ITER-15: fingerprint(of:) 的静态转发（实例方法依赖 self 无状态，仅访问参数），
    /// 供 layoutHasSnapshotItems 与单测使用。语义与实例版完全一致。
    fileprivate static func instanceFingerprint(of item: NSTouchBarItem) -> ItemFingerprint? {
        if let bi = item as? CustomButtonTouchBarItem {
            return .button(
                imageRef: bi.image.map { ObjectIdentifier($0) },
                title: bi.attributedTitle,
                width: item.view?.frame.width ?? 0
            )
        }
        if let li = item as? LyricsTouchBarItem {
            return .text(lyricsTextStatic(from: li), width: item.view?.frame.width ?? 0)
        }
        if let gi = item as? GroupBarItem {
            return .text(gi.collapsedRepresentationLabel, width: 0)
        }
        return nil
    }

    private static func lyricsTextStatic(from li: LyricsTouchBarItem) -> String {
        var txt = "♫"
        if let stack = li.view as? NSStackView {
            for case let karaoke as KaraokeLabel in stack.arrangedSubviews {
                let s = karaoke.attributedStringValue.string.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    txt = s
                    break
                }
            }
        }
        return txt
    }

    /// 布局元素：item 或 分组分隔线
    private enum MirrorElement {
        case separator
        case item(NSTouchBarItem)
    }

    /// item 内容指纹。快照类 item（AppScrubber/音量/亮度/自定义视图等）无低成本指纹，
    /// fingerprint(of:) 返回 nil，由 syncFromTouchBar 的快照分支按 ITER-3 + ITER-9 节流
    /// （间隔随快照 item 数量自适应，1 个 5 tick / 2 个 7 tick / 3 个以上 10 tick）重建，
    /// 绝不永久冻结。
    /// `internal` (was `private`) so MTMRTests can unit-test the equality semantics
    /// via `@testable import` (ITER-6); no logic change.
    enum ItemFingerprint: Equatable {
        case button(imageRef: ObjectIdentifier?, title: NSAttributedString?, width: CGFloat)
        case text(String, width: CGFloat)

        static func == (lhs: ItemFingerprint, rhs: ItemFingerprint) -> Bool {
            switch (lhs, rhs) {
            case let (.button(aImage, aTitle, aWidth), .button(bImage, bTitle, bWidth)):
                guard aWidth == bWidth, aImage == bImage else { return false }
                switch (aTitle, bTitle) {
                case (nil, nil): return true
                case let (a?, b?): return a.isEqual(to: b)
                default: return false
                }
            case let (.text(a, aWidth), .text(b, bWidth)):
                return a == b && aWidth == bWidth
            default:
                return false
            }
        }
    }

    private static let separatorIdentifier = NSUserInterfaceItemIdentifier("mirror.separator")

    private func makeView(for target: MirrorElement) -> NSView {
        switch target {
        case .separator:
            let line = separatorLine()
            line.identifier = Self.separatorIdentifier
            return line
        case let .item(item):
            let v = makeItemView(for: item)
            v.identifier = NSUserInterfaceItemIdentifier(item.identifier.rawValue)
            return v
        }
    }

    private func view(_ view: NSView, matches target: MirrorElement) -> Bool {
        switch target {
        case .separator:
            return view.identifier == Self.separatorIdentifier
        case let .item(item):
            return view.identifier?.rawValue == item.identifier.rawValue
        }
    }

    private func replace(_ oldView: NSView, with newView: NSView, in sv: NSStackView, at index: Int) {
        sv.insertArrangedSubview(newView, at: index)
        sv.removeArrangedSubview(oldView)
        oldView.removeFromSuperview()
    }

    private func remember(_ view: NSView, for target: MirrorElement, identifiers: inout Set<NSTouchBarItem.Identifier>) {
        guard case let .item(item) = target else { return }
        identifiers.insert(item.identifier)
        if let fingerprint = fingerprint(of: item) {
            itemFingerprints[item.identifier] = fingerprint
        } else {
            itemFingerprints.removeValue(forKey: item.identifier)
        }
    }

    /// 计算 item 内容指纹；nil 表示该类型无法低成本指纹化（快照类，按 ITER-3 + ITER-9 节流重建）
    private func fingerprint(of item: NSTouchBarItem) -> ItemFingerprint? {
        if let bi = item as? CustomButtonTouchBarItem {
            return .button(
                imageRef: bi.image.map { ObjectIdentifier($0) },
                title: bi.attributedTitle,
                width: item.view?.frame.width ?? 0
            )
        }
        if let li = item as? LyricsTouchBarItem {
            return .text(lyricsText(from: li), width: item.view?.frame.width ?? 0)
        }
        if let gi = item as? GroupBarItem {
            return .text(gi.collapsedRepresentationLabel, width: 0)
        }
        return nil
    }

    private func separatorLine() -> NSBox {
        let b = NSBox()
        b.boxType = .separator
        b.translatesAutoresizingMaskIntoConstraints = false
        b.heightAnchor.constraint(equalToConstant: 20).isActive = true
        b.widthAnchor.constraint(equalToConstant: 1).isActive = true
        return b
    }

    private func makeItemView(for item: NSTouchBarItem) -> NSView {
        if let bi = item as? CustomButtonTouchBarItem {
            let btn = NSButton()
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.isBordered = bi.isBordered
            if bi.isBordered {
                btn.bezelStyle = .rounded
                if let c = bi.backgroundColor {
                    btn.bezelColor = c
                }
            } else {
                btn.bezelStyle = .inline
            }
            btn.imageScaling = .scaleProportionallyDown
            btn.imageHugsTitle = true
            if let img = bi.image {
                btn.image = img
                btn.imagePosition = bi.attributedTitle.length > 0 ? .imageLeading : .imageOnly
            }
            btn.attributedTitle = bi.attributedTitle
            btn.setContentCompressionResistancePriority(.required, for: .horizontal)
            btn.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            if let itemView = item.view, itemView.frame.width > 0 {
                btn.widthAnchor.constraint(equalToConstant: itemView.frame.width).isActive = true
            }
            return btn
        }

        if let gi = item as? GroupBarItem {
            let txt = gi.collapsedRepresentationLabel.isEmpty ? "▸" : "▸ " + gi.collapsedRepresentationLabel
            return simpleLabel(txt)
        }

        if let li = item as? LyricsTouchBarItem {
            let txt = lyricsText(from: li)
            let label = simpleLabel(txt)
            label.font = .systemFont(ofSize: 15, weight: .medium)
            if let itemView = item.view, itemView.frame.width > 0 {
                label.widthAnchor.constraint(equalToConstant: itemView.frame.width).isActive = true
            }
            return label
        }

        if let di = item as? AppScrubberTouchBarItem {
            if let snap = snapshot(di.view) { return snap }
            return simpleLabel("Dock")
        }

        if let _ = item as? UpNextScrubberTouchBarItem {
            let txt = extractText(from: item.view) ?? "UpNext"
            return simpleLabel(txt)
        }

        if let vi = item as? VolumeViewController {
            if let snap = snapshot(vi.view) { return snap }
            return simpleLabel("Vol")
        }

        if let bi = item as? BrightnessViewController {
            if let snap = snapshot(bi.view) { return snap }
            return simpleLabel("Bri")
        }

        if let ni = item as? NSCustomTouchBarItem {
            if let snap = snapshot(ni.view) { return snap }
            let txt = extractText(from: ni.view) ?? "?"
            return simpleLabel(txt)
        }

        return simpleLabel("?")
    }

    private func lyricsText(from li: LyricsTouchBarItem) -> String {
        var txt = "♫"
        if let stack = li.view as? NSStackView {
            for case let karaoke as KaraokeLabel in stack.arrangedSubviews {
                let s = karaoke.attributedStringValue.string.trimmingCharacters(in: .whitespaces)
                if !s.isEmpty {
                    txt = s
                    break
                }
            }
        }
        return txt
    }

    private func simpleLabel(_ text: String) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.textColor = .white
        l.font = .systemFont(ofSize: 13)
        l.alignment = .center
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        l.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return l
    }

    private func snapshot(_ view: NSView?) -> NSImageView? {
        guard let v = view, v.frame.width > 0, v.frame.height > 0 else { return nil }
        let size = v.bounds.size
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        let ctx = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        if v.wantsLayer, let layer = v.layer {
            layer.render(in: ctx!.cgContext)
        } else {
            v.cacheDisplay(in: v.bounds, to: v.bitmapImageRepForCachingDisplay(in: v.bounds)!)
        }
        NSGraphicsContext.restoreGraphicsState()
        let img = NSImage(size: size)
        img.addRepresentation(rep)
        let iv = NSImageView(image: img)
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.imageScaling = .scaleProportionallyDown
        return iv
    }

    private func extractText(from view: NSView?) -> String? {
        guard let v = view else { return nil }
        if let tf = v as? NSTextField {
            let s = tf.stringValue.trimmingCharacters(in: .whitespaces)
            if !s.isEmpty { return s }
        }
        if let b = v as? NSButton {
            let t = b.title.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        for sub in v.subviews {
            if let r = extractText(from: sub) { return r }
        }
        return nil
    }
}

class TouchBarBackgroundView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.92).cgColor
        layer?.cornerRadius = 6
        layer?.borderWidth = 0.5
        layer?.borderColor = NSColor(white: 0.25, alpha: 0.5).cgColor
    }
    required init?(coder: NSCoder) { return nil }
}
