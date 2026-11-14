import AppKit

/// Mirror 里"有状态组件"的最小可用方案：不再依赖第二套 item 实例自渲染，
/// 而是对实体栏同一个 item 的视图做 1Hz 快照。
///
/// 背景见 docs/架构债_Mirror第二套实例.md：Mirror 通过第二个 BarItemFactory
/// 造 item，而 item 同时是"视图 + 数据订阅者 + 定时器持有者"，歌词/upnext 这类
/// 有状态组件的第二实例拿不到可靠布局（GitHub issue #46）。
/// 这里是 Phase 1 最小修复：**先保证看得见**，实时滚动交给 Phase 2 的视图/数据拆分。
enum MirrorSnapshotPolicy {
    /// 需要快照兜底的有状态组件。
    static func shouldSnapshot(_ type: ItemType) -> Bool {
        switch type {
        case .lyrics, .upnext:
            return true
        default:
            return false
        }
    }

    /// 快照宽度上限（实体栏歌词区域大致就是这个量级）。
    static let maxWidth: CGFloat = 320

    static func preferredWidth(sourceWidth: CGFloat) -> CGFloat {
        min(maxWidth, max(28, sourceWidth))
    }
}

/// 把实体栏某个 item 的视图按 1Hz 渲染成图片，供 Mirror 显示。
final class MirrorSnapshotView: NSView {
    private let imageView = NSImageView()
    private weak var source: NSView?
    private var timer: Timer?
    private let placeholder = NSTextField(labelWithString: "")

    /// 渲染快照。纯函数式入口，测试可直接调用（不依赖 timer / window）。
    static func snapshot(of view: NSView, size: CGSize) -> NSImage? {
        guard size.width >= 1, size.height >= 1 else { return nil }
        let rect = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
        view.cacheDisplay(in: rect, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }

    init?(source: NSView) {
        self.source = source
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        placeholder.font = .systemFont(ofSize: 11)
        placeholder.textColor = .secondaryLabelColor
        placeholder.alignment = .center
        placeholder.lineBreakMode = .byTruncatingTail
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholder)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            placeholder.centerXAnchor.constraint(equalTo: centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        refresh()
        // 1Hz：够"看得见且在动"，又不和实体栏的 60fps 抢 CPU（Phase 1 取舍）
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        timer?.invalidate()
    }

    override var intrinsicContentSize: NSSize {
        let width = source.map { $0.bounds.width > 0 ? $0.bounds.width : $0.fittingSize.width } ?? 0
        return NSSize(width: MirrorSnapshotPolicy.preferredWidth(sourceWidth: width), height: 30)
    }

    /// 每秒重绘一次。源视图没尺寸/没画出来时退化为占位文案，而不是一片空白。
    func refresh() {
        guard let source else {
            placeholder.stringValue = localized("镜像不可用", "Mirror N/A")
            return
        }
        let width = source.bounds.width > 0 ? source.bounds.width : source.fittingSize.width
        let size = CGSize(width: MirrorSnapshotPolicy.preferredWidth(sourceWidth: width), height: 30)
        if let image = Self.snapshot(of: source, size: size), !Self.isBlank(image) {
            imageView.image = image
            imageView.isHidden = false
            placeholder.stringValue = ""
        } else {
            imageView.image = nil
            imageView.isHidden = true
            placeholder.stringValue = localized("歌词镜像等待实体栏…", "Waiting for hardware bar…")
        }
    }

    /// 空白图（全透明）视为失败：避免 Mirror 显示一块"看起来坏了"的空白。
    static func isBlank(_ image: NSImage) -> Bool {
        guard let rep = image.representations.first as? NSBitmapImageRep,
              rep.pixelsWide > 0, rep.pixelsHigh > 0 else { return true }
        let stepX = max(1, rep.pixelsWide / 8)
        let stepY = max(1, rep.pixelsHigh / 4)
        for y in stride(from: 0, to: rep.pixelsHigh, by: stepY) {
            for x in stride(from: 0, to: rep.pixelsWide, by: stepX) {
                if let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.02 {
                    return false
                }
            }
        }
        return true
    }
}
