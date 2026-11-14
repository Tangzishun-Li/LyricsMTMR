//
//  TouchBarSimulatorView.swift
//  LyricsMTMR
//
//  Native Touch Bar preview plus an explicit arrangement rail. The preview
//  shares Mirror's widget renderer; arrangement chips are editing controls.
//

import SwiftUI
import AppKit

enum TouchBarMetrics {
    static let physicalWidth: CGFloat = 1085
    static let physicalHeight: CGFloat = 42
    static let minZoneWidth: CGFloat = 60
    static let cornerRadius: CGFloat = 6
    static let pillHeight: CGFloat = 30
}

enum TouchBarZone: String, CaseIterable {
    case left, center, right
    var label: String { rawValue.prefix(1).uppercased() }
    var fullName: String {
        switch self {
        case .left: return localized("左侧固定", "Pinned left")
        case .center: return localized("中间滚动", "Scrolling center")
        case .right: return localized("右侧固定", "Pinned right")
        }
    }
}

enum DropPosition: Equatable { case before, after }

struct TouchBarSimulatorView: View {
    @ObservedObject var model: RibbonModel
    var isActive: Bool = true
    @State private var actualSize = false
    @State private var dragOverIndex: Int?
    @State private var dragOverPosition: DropPosition = .before
    @State private var zoneDropHover: TouchBarZone?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "touchbar")
                    .foregroundStyle(EditorColors.mintSwift)
                Text(localized("Touch Bar 预览", "Touch Bar Preview"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(EditorColors.textPrimarySwift)
                Text(model.editorMode == .edit
                     ? localized("点击选择组件", "Click to select a widget")
                     : localized("点击操作 · 滚动浏览", "Click to interact · Scroll to browse"))
                    .font(.system(size: 10))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                Spacer()
                Button { actualSize.toggle() } label: {
                    Label(actualSize ? localized("原始尺寸", "Actual size") : localized("适合窗口", "Fit to window"),
                          systemImage: actualSize ? "1.magnifyingglass" : "arrow.down.right.and.arrow.up.left")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(EditorColors.textSecondarySwift)
            }
            if actualSize {
                ScrollView(.horizontal, showsIndicators: true) {
                    nativePreview.frame(width: TouchBarSurfaceView.logicalWidth, height: 50)
                }
                .frame(height: 58)
            } else {
                nativePreview.frame(height: 50)
            }
            if let error = model.previewError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.system(size: 10))
                    .foregroundStyle(EditorColors.accentSwift)
            }
            if model.editorMode == .edit {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(TouchBarZone.allCases, id: \.self) { zone in
                        arrangementZone(zone)
                    }
                }
                Text(localized("拖动下方组件调整顺序或分区 · 双击容器编辑子项", "Drag widgets to reorder or change zones · Double-click a container to edit its contents"))
                    .font(.system(size: 10))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var nativePreview: some View {
        NativeTouchBarPreview(
            definitions: model.previewDefinitions,
            presetPath: model.currentThemePath,
            selectedIndex: model.selectedIndex,
            interactive: model.editorMode == .preview,
            isActive: isActive,
            onSelect: handleTap
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 1))
    }

    private func arrangementZone(_ zone: TouchBarZone) -> some View {
        let entries = model.activeItems.enumerated().filter { alignOf($0.element) == zone }
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(zone.fullName)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(entries.count)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
            .foregroundStyle(zoneDropHover == zone ? EditorColors.accentSwift : EditorColors.textSecondarySwift)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        if entries.isEmpty {
                            Text(localized("拖入组件", "Drop a widget here"))
                                .font(.system(size: 10))
                                .foregroundStyle(EditorColors.textTertiarySwift)
                                .frame(height: 26)
                        }
                        ForEach(entries, id: \.offset) { entry in
                            arrangementItem(entry.element, index: entry.offset, zone: zone)
                                .id(entry.offset)
                        }
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                }
                .onChange(of: model.scrollAnchor) { _, anchor in
                    guard let anchor else { return }
                    withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(anchor, anchor: .center) }
                }
            }
            .frame(height: 38)
            .background(EditorColors.cardSwift.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(zoneDropHover == zone ? EditorColors.accentSwift : EditorColors.hairlineSwift, lineWidth: 1))
            .onDrop(of: [.text], delegate: ZoneDropDelegate(
                zone: zone, model: model,
                onHover: { zoneDropHover = $0 ? zone : nil }
            ))
        }
        .frame(maxWidth: .infinity)
    }

    private func arrangementItem(_ item: [String: Any], index: Int, zone: TouchBarZone) -> some View {
        SimPill(item: item, index: index,
                isSelected: model.isSelected(index), isMultiMode: model.selectedIndices.count > 1,
                dropPosition: dragOverIndex == index ? dragOverPosition : nil,
                isEditMode: true, isCenterZone: zone == .center, scale: 1.1,
                onDelete: { model.delete(at: index) }, onTap: { handleTap(index) },
                onCopy: { model.select(index); model.copySelected() },
                onCut: { model.select(index); model.cutSelected() },
                onMoveToZone: { model.updatePropertyAtIndex(index, key: "align", value: $0.rawValue) },
                onDrillIn: { model.drillInto(index: index) })
            .onDrag {
                if !model.isSelected(index) { model.select(index) }
                return NSItemProvider(object: "\(index)" as NSString)
            }
            .onDrop(of: [.text], delegate: SimDropDelegate(
                targetIndex: index, zone: zone, model: model, width: 90,
                onHover: { dragOverIndex = $0 ? index : nil },
                onInsertion: { dragOverPosition = $0 }
            ))
    }

    private func alignOf(_ item: [String: Any]) -> TouchBarZone {
        TouchBarZone(rawValue: item["align"] as? String ?? "center") ?? .center
    }

    private func handleTap(_ index: Int) {
        guard index >= 0, index < model.activeItems.count else { return }
        if NSEvent.modifierFlags.contains(.command) { model.toggleSelect(index) }
        else if NSEvent.modifierFlags.contains(.shift) { model.rangeSelect(to: index) }
        else { model.select(index) }
    }
}

private struct NativeTouchBarPreview: NSViewRepresentable {
    let definitions: [BarItemDefinition]
    let presetPath: String
    let selectedIndex: Int?
    let interactive: Bool
    let isActive: Bool
    let onSelect: (Int) -> Void

    func makeNSView(context: Context) -> TouchBarSurfaceView {
        TouchBarSurfaceView(frame: .zero)
    }

    func updateNSView(_ view: TouchBarSurfaceView, context: Context) {
        view.presetPath = presetPath
        view.isInteractive = interactive
        view.onSelect = { identifier in
            guard let index = Int(identifier.rawValue.replacingOccurrences(of: "editor-item-", with: "")) else { return }
            onSelect(index)
        }
        if isActive {
            let identifiers = definitions.indices.map { NSTouchBarItem.Identifier("editor-item-\($0)") }
            view.update(definitions: definitions, identifiers: identifiers)
        }
        view.selectedIdentifier = selectedIndex.map { NSTouchBarItem.Identifier("editor-item-\($0)") }
        view.setPaused(!isActive)
    }

    static func dismantleNSView(_ view: TouchBarSurfaceView, coordinator: ()) {
        view.dispose()
    }
}

// MARK: - Sim Pill (zone-aware, with context menu)

struct SimPill: View {
    let item: [String: Any]
    let index: Int
    let isSelected: Bool
    let isMultiMode: Bool
    let dropPosition: DropPosition?
    let isEditMode: Bool
    let isCenterZone: Bool
    let scale: CGFloat
    let onDelete: () -> Void
    let onTap: () -> Void
    let onCopy: () -> Void
    let onCut: () -> Void
    let onMoveToZone: (TouchBarZone) -> Void
    let onDrillIn: () -> Void

    @State private var hovering = false

    private var type: String { item["type"] as? String ?? "unknown" }
    private var schema: ItemSchema { EditorSchema.schema(for: type) }
    private var hasChildren: Bool {
        item["items"] != nil || schema.hasPopup
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
                            dropPosition != nil ? EditorColors.accentSwift
                                : (isSelected ? EditorColors.accentSwift.opacity(0.8) : Color(white: 0.22)),
                            lineWidth: dropPosition != nil ? 1.5 : (isSelected ? 1 : 0.5)
                        )
                )
                .overlay(alignment: dropPosition == .before ? .leading : .trailing) {
                    if dropPosition != nil {
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(EditorColors.accentSwift)
                            .frame(width: 2.5, height: 14 * max(scale, 0.7))
                            .padding(.horizontal, -1.5)
                    }
                }
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
        if isEditMode {
            Button(action: onCopy) {
                Label(localized("复制", "Copy"), systemImage: "doc.on.doc")
            }
            Button(action: onCut) {
                Label(localized("剪切", "Cut"), systemImage: "scissors")
            }
            Divider()
        }

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
        case "timeButton": return schema.displayName
        case "stock":
            let stocks = item["stocks"] as? [String] ?? []
            return stocks.first ?? "Stock"
        case "lyrics": return "♫"
        case "dock": return "Dock"
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
        // Arrangement chips are labels, not a second approximation of the
        // hardware geometry. Native widgets above are the actual preview.
        return nil
    }
}

// MARK: - Drop delegate (reuses existing pattern)

struct SimDropDelegate: DropDelegate {
    let targetIndex: Int
    let zone: TouchBarZone
    let model: RibbonModel
    let width: CGFloat
    let onHover: (Bool) -> Void
    let onInsertion: (DropPosition) -> Void

    func dropEntered(info: DropInfo) { onHover(true) }
    func dropExited(info: DropInfo) { onHover(false) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        onHover(true)
        onInsertion(info.location.x < width / 2 ? .before : .after)
        return DropProposal(operation: .move)
    }
    func performDrop(info: DropInfo) -> Bool {
        onHover(false)
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String else { return }
            let dest = info.location.x < width / 2 ? targetIndex : targetIndex + 1
            DispatchQueue.main.async {
                if str.hasPrefix("palette:") {
                    let type = String(str.dropFirst("palette:".count))
                    model.add(type: type, at: dest, aligningTo: zone)
                } else if let from = Int(str) {
                    model.moveSelected(from: from, to: dest, aligningTo: zone)
                }
            }
        }
        return true
    }
}

// MARK: - Zone drop delegate

/// Drop target for a whole zone: appends the dragged item to the zone.
struct ZoneDropDelegate: DropDelegate {
    let zone: TouchBarZone
    let model: RibbonModel
    let onHover: (Bool) -> Void

    func dropEntered(info: DropInfo) { onHover(true) }
    func dropExited(info: DropInfo) { onHover(false) }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        onHover(false)
        guard let provider = info.itemProviders(for: [.text]).first else { return false }
        provider.loadObject(ofClass: NSString.self) { reading, _ in
            guard let str = reading as? String else { return }
            DispatchQueue.main.async {
                guard let dest = model.insertPosition(forZone: zone) else { return }
                if str.hasPrefix("palette:") {
                    let type = String(str.dropFirst("palette:".count))
                    model.add(type: type, at: dest, aligningTo: zone)
                } else if let from = Int(str) {
                    model.moveSelected(from: from, to: dest, aligningTo: zone)
                }
            }
        }
        return true
    }
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
