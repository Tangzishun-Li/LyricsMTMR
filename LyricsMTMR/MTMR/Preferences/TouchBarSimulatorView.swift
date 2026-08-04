//
//  TouchBarSimulatorView.swift
//  LyricsMTMR
//
//  Three-zone Touch Bar simulator: fixed left/right, elastic center.
//  Replaces the flat TouchBarStrip with a physically accurate preview.
//

import SwiftUI

// MARK: - Physical constants

enum TouchBarMetrics {
    /// MacBook Pro 13" 2016-2020 physical Touch Bar width in points.
    static let physicalWidth: CGFloat = 1002
    /// Physical height in points.
    static let physicalHeight: CGFloat = 30
    /// Minimum zone width so handles remain grabbable.
    static let minZoneWidth: CGFloat = 60
    /// Bezel corner radius.
    static let cornerRadius: CGFloat = 6
    /// Item pill height inside the bar.
    static let pillHeight: CGFloat = 24
}

// MARK: - Zone classification helper

enum TouchBarZone: String, CaseIterable {
    case left, center, right

    var label: String {
        switch self {
        case .left: return "L"
        case .center: return "C"
        case .right: return "R"
        }
    }

    var fullName: String {
        switch self {
        case .left: return localized("左区", "Left")
        case .center: return localized("中区", "Center")
        case .right: return localized("右区", "Right")
        }
    }
}

// MARK: - Simulator View

struct TouchBarSimulatorView: View {
    @ObservedObject var model: RibbonModel

    /// Fraction of total width allocated to center (0.2...0.8). Dragging handles adjusts this.
    @State private var centerFraction: CGFloat = 0.55
    @State private var dragOverIndex: Int?
    @State private var hoveredZone: TouchBarZone?
    @State private var scrollOffset: CGFloat = 0
    @State private var trashHovering = false

    // MARK: Zone-split items

    private var leftItems: [(index: Int, item: [String: Any])] {
        model.activeItems.enumerated()
            .filter { alignOf($0.element) == .left }
            .map { ($0.offset, $0.element) }
    }

    private var centerItems: [(index: Int, item: [String: Any])] {
        model.activeItems.enumerated()
            .filter { alignOf($0.element) == .center }
            .map { ($0.offset, $0.element) }
    }

    private var rightItems: [(index: Int, item: [String: Any])] {
        model.activeItems.enumerated()
            .filter { alignOf($0.element) == .right }
            .map { ($0.offset, $0.element) }
    }

    private func alignOf(_ item: [String: Any]) -> TouchBarZone {
        switch item["align"] as? String {
        case "left": return .left
        case "right": return .right
        default: return .center
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.width - 28 // outer padding
            let scale = min(available / TouchBarMetrics.physicalWidth, 1.0)
            let barWidth = TouchBarMetrics.physicalWidth * scale
            let barHeight = TouchBarMetrics.physicalHeight * scale
            let needsScroll = available < TouchBarMetrics.physicalWidth

            VStack(spacing: 6) {
                // ── Touch Bar bezel ──
                ZStack {
                    // Outer shell
                    RoundedRectangle(cornerRadius: TouchBarMetrics.cornerRadius + 2, style: .continuous)
                        .fill(Color.black)
                        .frame(width: barWidth + 10, height: barHeight + 10)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 2)

                    // Screen
                    RoundedRectangle(cornerRadius: TouchBarMetrics.cornerRadius, style: .continuous)
                        .fill(Color(white: 0.06))
                        .frame(width: barWidth, height: barHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: TouchBarMetrics.cornerRadius, style: .continuous)
                                .strokeBorder(Color(white: 0.18), lineWidth: 0.5)
                        )

                    // Three-zone content
                    HStack(spacing: 0) {
                        zoneView(.left, items: leftItems, scale: scale)
                            .frame(width: barWidth * ((1 - centerFraction) / 2))

                        dragHandle

                        zoneView(.center, items: centerItems, scale: scale, isCenter: true)
                            .frame(width: barWidth * centerFraction - 12)

                        dragHandle

                        zoneView(.right, items: rightItems, scale: scale)
                            .frame(width: barWidth * ((1 - centerFraction) / 2))
                    }
                    .frame(width: barWidth - 4, height: barHeight - 4)
                }

                // ── Scroll indicator (when window is narrow) ──
                if needsScroll {
                    scrollIndicator(available: available, barWidth: barWidth)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .bottomTrailing) {
                if model.editorMode == .edit {
                    trashCanView
                        .padding(.trailing, 18)
                        .padding(.bottom, 2)
                }
            }
        }
    }

    // MARK: - Zone view

    private func zoneView(_ zone: TouchBarZone, items: [(index: Int, item: [String: Any])], scale: CGFloat, isCenter: Bool = false) -> some View {
        ZStack {
            // Zone background
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(isCenter ? Color(white: 0.10) : Color(white: 0.07))

            // Zone label (top-left, subtle)
            VStack {
                HStack {
                    Text(hoveredZone == zone ? zone.fullName : zone.label)
                        .font(.system(size: 7 * max(scale, 0.7), weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(white: 0.3))
                    Spacer()
                }
                .padding(.leading, 4)
                .padding(.top, 2)
                Spacer()
            }

            // Items
            ScrollView(.horizontal, showsIndicators: false) {
                itemsHStack(items, zone: zone, scale: scale)
            }
        }
        .onHover { hovering in
            hoveredZone = hovering ? zone : nil
        }
    }

    private func itemsHStack(_ items: [(index: Int, item: [String: Any])], zone: TouchBarZone, scale: CGFloat) -> some View {
        HStack(spacing: 3) {
            if items.isEmpty {
                Text(zone.fullName)
                    .font(.system(size: 8 * max(scale, 0.7), weight: .medium))
                    .foregroundStyle(Color(white: 0.2))
            } else {
                ForEach(items, id: \.index) { entry in
                    SimPill(
                        item: entry.item,
                        index: entry.index,
                        isSelected: model.isSelected(entry.index),
                        isMultiMode: model.selectedIndices.count > 1,
                        isDropTarget: dragOverIndex == entry.index,
                        isEditMode: model.editorMode == .edit,
                        isCenterZone: zone == .center,
                        scale: scale,
                        onDelete: { model.delete(at: entry.index) },
                        onTap: { handleTap(entry.index) },
                        onMoveToZone: { newZone in moveToZone(entry.index, zone: newZone) },
                        onDrillIn: { model.drillInto(index: entry.index) }
                    )
                    .onDrag {
                        if model.editorMode == .edit {
                            model.select(entry.index)
                            return NSItemProvider(object: "\(entry.index)" as NSString)
                        }
                        return NSItemProvider()
                    }
                    .onDrop(of: [.text], delegate: SimDropDelegate(
                        targetIndex: entry.index,
                        model: model,
                        onHover: { hovering in dragOverIndex = hovering ? entry.index : nil }
                    ))
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    // MARK: - Drag handle between zones

    private var dragHandle: some View {
        Rectangle()
            .fill(Color(white: 0.25))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
            .padding(.vertical, 4)
            .overlay(
        RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.35))
                    .frame(width: 5, height: 16)
            )
            .contentShape(Rectangle().inset(by: -4))
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let delta = value.translation.width / TouchBarMetrics.physicalWidth
                        let newFraction = centerFraction - delta * 0.5
                        centerFraction = min(max(newFraction, 0.2), 0.8)
                    }
            )
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
    }

    // MARK: - Scroll indicator

    private func scrollIndicator(available: CGFloat, barWidth: CGFloat) -> some View {
        let ratio = available / barWidth
        return HStack(spacing: 4) {
            Image(systemName: "arrow.left")
                .font(.system(size: 7))
                .foregroundStyle(Color(white: 0.3))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.12))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(EditorColors.accentSwift.opacity(0.5))
                        .frame(width: geo.size.width * min(ratio, 1.0), height: 4)
                        .offset(x: scrollOffset * (geo.size.width * (1 - min(ratio, 1.0))))
                }
            }
            .frame(height: 4)
            Image(systemName: "arrow.right")
                .font(.system(size: 7))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Actions

    private func handleTap(_ index: Int) {
        let cmdPressed = NSEvent.modifierFlags.contains(.command)
        let shiftPressed = NSEvent.modifierFlags.contains(.shift)

        if cmdPressed {
            model.toggleSelect(index)
        } else if shiftPressed {
            model.rangeSelect(to: index)
        } else {
            model.select(index)
        }
    }

    private func moveToZone(_ index: Int, zone: TouchBarZone) {
        model.updatePropertyAtIndex(index, key: "align", value: zone.rawValue)
    }

    // MARK: - Trash can

    private var trashCanView: some View {
        Image(systemName: trashHovering ? "trash.fill" : "trash")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(trashHovering ? Color.red : Color(white: 0.3))
            .frame(width: 34, height: 26)
            .background {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(trashHovering ? Color.red.opacity(0.12) : Color(white: 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                trashHovering ? Color.red.opacity(0.6) : Color(white: 0.2),
                                lineWidth: trashHovering ? 1.5 : 0.5
                            )
                    )
            }
            .scaleEffect(trashHovering ? 1.15 : 1.0)
            .onDrop(of: [.text], delegate: TrashDropDelegate(
                model: model,
                onHover: { hovering in trashHovering = hovering }
            ))
            .animation(.easeOut(duration: 0.12), value: trashHovering)
            .help(localized("拖到此处删除", "Drag here to delete"))
    }
}

// MARK: - Sim Pill (zone-aware, with context menu)

struct SimPill: View {
    let item: [String: Any]
    let index: Int
    let isSelected: Bool
    let isMultiMode: Bool
    let isDropTarget: Bool
    let isEditMode: Bool
    let isCenterZone: Bool
    let scale: CGFloat
    let onDelete: () -> Void
    let onTap: () -> Void
    let onMoveToZone: (TouchBarZone) -> Void
    let onDrillIn: () -> Void

    @State private var hovering = false

    private var type: String { item["type"] as? String ?? "unknown" }
    private var schema: ItemSchema { EditorSchema.schema(for: type) }
    private var hasChildren: Bool {
        (item["items"] as? [[String: Any]])?.isEmpty == false
    }

    var body: some View {
        HStack(spacing: 2) {
            if isMultiMode && isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 7 * max(scale, 0.7), weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 9)
            } else {
                Image(systemName: schema.symbol)
                    .font(.system(size: 8 * max(scale, 0.7), weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color(white: 0.5))
                    .frame(width: 10)
            }

            Text(displayText)
                .font(.system(size: 9.5 * max(scale, 0.7), weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Color(white: 0.75))
                .lineLimit(1)

            // Container indicator
            if hasChildren {
                Image(systemName: "chevron.right")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(Color(white: 0.4))
            }

            if hovering && isEditMode {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.7) : Color(white: 0.35))
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 6 * max(scale, 0.7))
        .padding(.vertical, 4 * max(scale, 0.7))
        .frame(minWidth: 32 * max(scale, 0.7))
        .frame(width: pillWidth)
        .background {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(isSelected
                    ? EditorColors.accentSwift
                    : (hovering ? Color(white: 0.16) : Color(white: 0.11)))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(
                            isDropTarget ? EditorColors.accentSwift
                                : (isSelected ? EditorColors.accentSwift.opacity(0.8) : Color(white: 0.22)),
                            lineWidth: isDropTarget ? 1.5 : (isSelected ? 1 : 0.5)
                        )
                )
        }
        .onTapGesture(count: 2) {
            if hasChildren { onDrillIn() }
        }
        .onTapGesture { onTap() }
        .onHover { hv in withAnimation(.easeOut(duration: 0.1)) { hovering = hv } }
        .contextMenu { contextMenuItems }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if hasChildren {
            Button(action: onDrillIn) {
                Label(localized("编辑子项", "Edit Children"), systemImage: "square.stack.3d.down.right")
            }
            Divider()
        }

        if isEditMode {
            Menu(localized("移动到", "Move to")) {
                ForEach(TouchBarZone.allCases, id: \.self) { zone in
                    Button(action: { onMoveToZone(zone) }) {
                        Label(zone.fullName, systemImage: zone == .left ? "align.horizontal.left" : zone == .center ? "align.horizontal.center" : "align.horizontal.right")
                    }
                    .disabled(alignOf(item) == zone)
                }
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label(localized("删除", "Delete"), systemImage: "trash")
            }
        }
    }

    private func alignOf(_ item: [String: Any]) -> TouchBarZone {
        switch item["align"] as? String {
        case "left": return .left
        case "right": return .right
        default: return .center
        }
    }

    private var displayText: String {
        if let title = item["title"] as? String, !title.isEmpty { return title }
        switch type {
        case "timeButton":
            let fmt = item["formatTemplate"] as? String ?? "HH:mm"
            let df = DateFormatter(); df.dateFormat = fmt
            return df.string(from: Date())
        case "battery": return "87%"
        case "cpu": return "12%"
        case "volume": return "▮▮▯"
        case "brightness": return "☀▮▮"
        case "weather": return "26°"
        case "stock":
            let stocks = item["stocks"] as? [String] ?? []
            return stocks.first ?? "AAPL"
        case "lyrics": return "♫"
        case "dock": return "Dock"
        case "pomodoro": return "25:00"
        case "themeSwitch": return "⚙"
        case "deepseekBalance": return "DS"
        case "opencodeGoUsage": return "Go"
        case "escape": return "esc"
        case "group":
            let children = item["items"] as? [[String: Any]] ?? []
            return "G(\(children.count))"
        case "expandable":
            let children = item["items"] as? [[String: Any]] ?? []
            return "E(\(children.count))"
        default: return schema.displayName
        }
    }

    private var pillWidth: CGFloat? {
        if let w = item["width"] as? Int { return CGFloat(min(w, 180)) * scale }
        if let w = item["width"] as? Double { return CGFloat(min(w, 180)) * scale }
        return nil
    }
}

// MARK: - Drop delegate (reuses existing pattern)

struct SimDropDelegate: DropDelegate {
    let targetIndex: Int
    let model: RibbonModel
    let onHover: (Bool) -> Void

    func dropEntered(info: DropInfo) { onHover(true) }
    func dropExited(info: DropInfo) { onHover(false) }
    func performDrop(info: DropInfo) -> Bool {
        onHover(false)
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String, let from = Int(str) else { return }
            DispatchQueue.main.async {
                model.move(from: from, to: targetIndex)
            }
        }
        return true
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

// MARK: - Trash drop delegate

struct TrashDropDelegate: DropDelegate {
    let model: RibbonModel
    let onHover: (Bool) -> Void

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropEntered(info: DropInfo) { onHover(true) }
    func dropExited(info: DropInfo) { onHover(false) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        onHover(false)
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String, let index = Int(str) else { return }
            DispatchQueue.main.async {
                model.delete(at: index)
            }
        }
        return true
    }
}
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
