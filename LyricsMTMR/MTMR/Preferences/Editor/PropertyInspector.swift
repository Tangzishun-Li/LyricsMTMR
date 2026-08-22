//
//  PropertyInspector.swift
//  LyricsMTMR
//
//  Dynamic property inspector driven by EditorSchema.
//  Section-grouped properties, collapsible headers, conditional visibility,
//  new controls (stringList, slider, filePicker, colorPicker), container drill-in.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - r57-d 跳转契约（docs/轨道文本_R57_设置体系治理.md §6，Notification.Name 冻结）

extension Notification.Name {
    /// 设置窗口 → 编辑器：定位并选中某 item。userInfo: ["type": String, "index": Int?]
    static let settingsNavigateToItem = Notification.Name("com.lyricsmtmr.settings.navigateToItem")
    /// 编辑器 → 设置窗口：打开某域 tab。userInfo: ["tab": String]  // SettingsTab.rawValue
    static let editorRequestOpenSettings = Notification.Name("com.lyricsmtmr.editor.openSettings")
}

struct PropertyInspector: View {
    @ObservedObject var model: RibbonModel
    @State private var showKeyCapture: Bool = false
    /// r57-d：设置窗口请求的待定位 item（type + index）。
    /// 直接通知路径立即消费；编辑器 tab 未构建时由 UnifiedSettingsWindowController
    /// 的 pendingNavigation 暂存，经 .settingsNavigateToItem 二次投递后在此消费。
    @State private var pendingNavigationItem: (type: String, index: Int?)? = nil

    private let gridColumns = [
        GridItem(.flexible(minimum: 180), spacing: 16),
        GridItem(.flexible(minimum: 180), spacing: 16),
    ]

    var body: some View {
        Group {
            if model.selectedIndices.isEmpty {
                emptyState
            } else if model.selectedIndices.count == 1,
                      let index = model.selectedIndex,
                      index < model.activeItems.count {
                let item = model.activeItems[index]
                inspectorContent(item: item, index: index)
            } else {
                multiSelectState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // r57-d ①设置→编辑器（直接路径）：编辑器已挂载时立即定位选中；
        // 数据尚未加载（首开）则先暂存，等 items 就绪后由下方兜底路径消费。
        .onReceive(NotificationCenter.default.publisher(for: .settingsNavigateToItem)) { note in
            guard let type = note.userInfo?["type"] as? String else { return }
            let index = note.userInfo?["index"] as? Int
            if model.items.isEmpty {
                pendingNavigationItem = (type, index)
            } else {
                consumeNavigation(type: type, index: index)
            }
        }
        // 兜底路径：编辑器 tab 后构建 / 首次加载完成，items 就绪后补投递一次。
        .onReceive(model.$items) { _ in
            guard let pending = pendingNavigationItem else { return }
            pendingNavigationItem = nil
            consumeNavigation(type: pending.type, index: pending.index)
        }
    }

    // MARK: - r57-d 双向跳转

    /// ①设置→编辑器：定位并选中目标 item（顶层索引；容器子项仅按 type 匹配顶层）。
    /// 成功消费后清空窗口侧的 pendingNavigation，防止二次投递重复触发。
    private func consumeNavigation(type: String, index: Int?) {
        var target = index
        // 校验或按 type 搜索顶层 item；JSON 桥接的 items 可能是 NSNumber，做数值归一比较。
        if let i = target, i >= model.items.count || itemType(at: i) != type {
            target = nil
        }
        if target == nil {
            target = model.items.firstIndex { itemTypeMatches($0, type) }
        }
        guard let idx = target, idx < model.items.count else { return }

        // 回到根层级再选中（drill-in 状态下 activeItems 是子项数组）。
        if !model.navigationPath.isEmpty {
            model.navigateToRoot()
        }
        model.select(idx)
        model.scrollAnchor = idx   // 触发模拟条滚动到该 pill 并居中
        SettingsWindowState.shared.pendingNavigation = nil
    }

    private func itemType(at index: Int) -> String? {
        guard index >= 0, index < model.items.count else { return nil }
        let raw = model.items[index]["type"]
        return (raw as? String) ?? (raw as? NSNumber)?.stringValue
    }

    /// JSON 桥接下 type 可能是 String 也可能是 NSNumber（纯数字键），归一比较。
    private func itemTypeMatches(_ item: [String: Any], _ expected: String?) -> Bool {
        guard let raw = item["type"] else { return false }
        let value = (raw as? String) ?? (raw as? NSNumber)?.stringValue
        guard let value else { return false }
        guard let expected else { return true }
        return value == expected
    }

    /// ②编辑器→设置：item type → 域级设置 tab 映射（§7 D 卡验收：≥1 处真实入口）。
    /// music/lyrics 类 item → 歌词 tab，stock → 股票 tab……未映射的类型不显示按钮。
    private var domainSettingsTab: SettingsTab? {
        guard let index = model.selectedIndex,
              index < model.activeItems.count,
              let type = model.activeItems[index]["type"] as? String else { return nil }
        switch type {
        case "lyrics", "music", "upnext", "playbackProgress", "audioSpectrum":
            return .lyrics
        case "stock":
            return .stock
        case "pomodoro":
            return .pomodoro
        case "weather":
            return .weather
        case "rssUnread":
            return .rss
        case "packageTracker":
            return .package
        case "meetingCountdown", "holidayCountdown", "classCountdown", "ddlList":
            return .calendar
        case "homekitScene":
            return .homekit
        case "deepseekBalance", "aiSelectedText", "apiTester", "apiLatency":
            return .ai
        case "expenseTracker", "creditCardDue", "savingsGoal", "billSplit", "taxEstimate":
            return .expense
        case "dock":
            return .dock
        case "dnd", "slackUnread", "emailBadge", "quickReply":
            return .notification
        case "cpu", "networkSpeed", "systemTemp", "diskIO", "serverMonitor", "dockerStatus":
            return .systemMonitor
        case "postureReminder", "readTimer", "breathingGuide", "readingProgress":
            return .wellness
        case "foodDelivery", "weatherOutfit", "pixelPet":
            return .lifestyle
        default:
            return nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(EditorColors.textTertiarySwift)
            Text(localized("选择一个 Touch Bar 元素以编辑属性", "Select a Touch Bar item to edit its properties"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(EditorColors.textSecondarySwift)
                .multilineTextAlignment(.center)
            Text(localized("⌘+点击 多选 · ⇧+点击 连选 · 双击容器进入子项", "⌘+click multi · ⇧+click range · Double-click container to enter"))
                .font(.system(size: 11))
                .foregroundStyle(EditorColors.textTertiarySwift)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 40)
    }

    private var multiSelectState: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EditorColors.cardSwift)
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(localized("已选 \(model.selectedIndices.count) 项", "\(model.selectedIndices.count) items selected"))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(EditorColors.textPrimarySwift)
                    Text(localized("使用 ⌘C 复制 · ⌘X 剪切 · Delete 删除", "⌘C copy · ⌘X cut · Delete remove"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                }

                Spacer()

                Button(action: { model.deleteSelected() }) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EditorColors.accentDeepSwift)
                }
                .buttonStyle(.plain)
                .disabled(model.editorMode != .edit)
                .help(localized("删除选中", "Delete selected"))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            selectedTypesSummary
                .padding(.horizontal, 24)
        }
    }

    private var selectedTypesSummary: some View {
        let types = model.selectedIndices.compactMap { idx -> String? in
            guard idx >= 0, idx < model.activeItems.count else { return nil }
            return model.activeItems[idx]["type"] as? String
        }
        let counts = Dictionary(grouping: types, by: { $0 }).mapValues { $0.count }

        return HStack(spacing: 8) {
            ForEach(counts.sorted(by: { $0.value > $1.value }), id: \.key) { type, count in
                let schema = EditorSchema.schema(for: type)
                HStack(spacing: 4) {
                    Image(systemName: schema.symbol)
                        .font(.system(size: 9, weight: .medium))
                    Text("\(count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(EditorColors.textSecondarySwift)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule().fill(EditorColors.cardSwift.opacity(0.6))
                }
            }
            Spacer()
        }
    }

    private func inspectorContent(item: [String: Any], index: Int) -> some View {
        let type = item["type"] as? String ?? "unknown"
        let schema = EditorSchema.schema(for: type)
        let sections = schema.sectionedProperties

        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(type: type, schema: schema, index: index)

                // Container drill-in button
                if schema.hasPopup || (item["items"] as? [[String: Any]]) != nil {
                    drillInButton(index: index, schema: schema)
                }

                diagnostics(item: item)

                // Shortcut binding section (when action is appleScript with key code)
                shortcutSection(item: item, index: index)

                // Section-grouped properties
                ForEach(sections, id: \.section) { section in
                    sectionView(section: section, item: item)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Section view (collapsible)

    // MARK: - Shortcut binding section

    @ViewBuilder
    private func shortcutSection(item: [String: Any], index: Int) -> some View {
        let action = item["action"] as? String ?? ""
        let scriptDict = item["actionAppleScript"] as? [String: Any]
        let inline = scriptDict?["inline"] as? String ?? ""
        let parsed = AppleScriptGenerator.parseKeyCombo(from: inline)

        if action == "appleScript" || parsed != nil {
            VStack(alignment: .leading, spacing: 10) {
                // Section header
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                    Text(localized("快捷键", "Shortcut"))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                        .textCase(.uppercase)
                    Rectangle()
                        .fill(EditorColors.hairlineSwift)
                        .frame(height: 1)
                }

                if let combo = parsed {
                    // Show current binding
                    HStack(spacing: 8) {
                        // Keycap display
                        HStack(spacing: 3) {
                            ForEach(combo.modifiers.sorted(by: { $0.sortOrder < $1.sortOrder })) { mod in
                                Text(mod.symbol)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(EditorColors.textPrimarySwift)
                                    .frame(width: 26, height: 26)
                                    .background {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(EditorColors.cardSwift)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 5)
                                                    .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.8)
                                            )
                                    }
                            }
                            Text(KeyCodeMap.label(for: combo.keyCode))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(EditorColors.accentSwift)
                                .frame(minWidth: 26, minHeight: 26)
                                .padding(.horizontal, 4)
                                .background {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(EditorColors.accentSwift.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 5)
                                                .strokeBorder(EditorColors.accentSwift.opacity(0.5), lineWidth: 0.8)
                                        )
                                }
                        }

                        Text("keyCode \(combo.keyCode)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(EditorColors.textTertiarySwift)

                        Spacer()

                        // Modify button
                        Button(action: { showKeyCapture = true }) {
                            HStack(spacing: 3) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 9, weight: .semibold))
                                Text(localized("修改", "Edit"))
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(EditorColors.accentSwift)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(EditorColors.accentSwift.opacity(0.1))
                            }
                        }
                        .buttonStyle(.plain)

                        // Clear button
                        Button(action: {
                            var src = model.activeItems
                            KeyBindingStore.clearBinding(from: &src[index])
                            model.activeItems = src
                            model.didMutate()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                Text(localized("清除", "Clear"))
                                    .font(.system(size: 10.5, weight: .medium))
                            }
                            .foregroundStyle(EditorColors.accentDeepSwift)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(EditorColors.accentDeepSwift.opacity(0.08))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    // No binding yet: offer to add one
                    Button(action: { showKeyCapture = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11, weight: .semibold))
                            Text(localized("绑定快捷键", "Bind Shortcut"))
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(EditorColors.accentSwift)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(EditorColors.accentSwift.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .strokeBorder(EditorColors.accentSwift.opacity(0.25), lineWidth: 0.5)
                                )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .popover(isPresented: $showKeyCapture, arrowEdge: .bottom) {
                compactKeyCapture(index: index)
            }
        }
    }

    private func compactKeyCapture(index: Int) -> some View {
        let captureStore = KeyBindingStore()
        return VStack(spacing: 10) {
            Text(localized("按下组合键完成绑定", "Press combo to bind"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(EditorColors.textPrimarySwift)

            VirtualKeyboardView(store: captureStore, onKeyCombo: { keyCode, modifiers in
                var src = model.activeItems
                KeyBindingStore.applyBinding(to: &src[index], keyCode: keyCode, modifiers: modifiers)
                model.activeItems = src
                model.didMutate()
                showKeyCapture = false
            }, compact: true)
        }
        .padding(14)
        .frame(width: 680)
        .background(EditorColors.bgSwift)
    }

    private func sectionView(section: (section: String, props: [ItemProperty]), item: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 6) {
                Text(section.section)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                    .textCase(.uppercase)
                Rectangle()
                    .fill(EditorColors.hairlineSwift)
                    .frame(height: 1)
            }
            .padding(.top, 4)

            LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 16) {
                ForEach(section.props) { property in
                    // Conditional visibility via dependsOn
                    if shouldShow(property: property, item: item) {
                        propertyCell(property: property, item: item)
                    }
                }
            }
        }
    }

    private func shouldShow(property: ItemProperty, item: [String: Any]) -> Bool {
        guard let dep = property.dependsOn else { return true }
        // Show this property only if the dependency key is truthy
        if let b = item[dep] as? Bool { return b }
        if let s = item[dep] as? String { return !s.isEmpty && s != "false" && s != "0" }
        if let n = item[dep] as? Int { return n != 0 }
        return item[dep] != nil
    }

    // MARK: - Drill-in button for containers

    private func drillInButton(index: Int, schema: ItemSchema) -> some View {
        let children = model.activeItems[index]["items"] as? [[String: Any]] ?? []
        return Button(action: { model.drillInto(index: index) }) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.down.right")
                    .font(.system(size: 12, weight: .semibold))
                Text(localized("进入编辑子项", "Edit Children"))
                    .font(.system(size: 12, weight: .semibold))
                Text("(\(children.count))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
            }
            .foregroundStyle(EditorColors.accentSwift)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(EditorColors.accentSwift.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(EditorColors.accentSwift.opacity(0.25), lineWidth: 0.5)
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private func header(type: String, schema: ItemSchema, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: schema.symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EditorColors.accentSwift)
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(EditorColors.cardSwift)
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(schema.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(EditorColors.textPrimarySwift)
                    if schema.requiresAPIKey {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.35))
                            .help(localized("需要 API 密钥", "Requires API key"))
                    }
                }
                HStack(spacing: 6) {
                    Text(type)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(EditorColors.textTertiarySwift)
                    if !schema.description.isEmpty {
                        Text("·")
                            .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.4))
                        Text(schema.description)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EditorColors.textTertiarySwift)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            // r57-d ②：编辑器→设置域 tab 跳转入口（有映射的类型才显示）
            if let domainTab = domainSettingsTab {
                Button(action: {
                    NotificationCenter.default.post(
                        name: .editorRequestOpenSettings,
                        object: nil,
                        userInfo: ["tab": domainTab.rawValue]   // §6 契约：userInfo ["tab": String]
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11, weight: .semibold))
                        Text(localized("域设置…", "Domain Settings…"))
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(EditorColors.textSecondarySwift)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(EditorColors.cardSwift)
                            .overlay(Capsule().strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.6))
                    }
                }
                .buttonStyle(.plain)
                .help(localized("打开「\(domainTab.title)」设置", "Open \(domainTab.title) settings"))
            }

            Button(action: { model.duplicateSelected() }) {
                Image(systemName: "plus.square.on.square")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorColors.textSecondarySwift)
            }
            .buttonStyle(.plain)
            .disabled(model.editorMode != .edit)
            .help(localized("复制此元素", "Duplicate this item"))

            Button(action: { model.deleteSelected() }) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(EditorColors.accentDeepSwift)
            }
            .buttonStyle(.plain)
            .disabled(model.editorMode != .edit)
            .help(localized("删除此元素", "Delete this item"))
        }
        .padding(.bottom, 4)
    }

    private func diagnostics(item: [String: Any]) -> some View {
        let issues = diagnose(item)
        if issues.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues, id: \.0) { symbol, text in
                    HStack(spacing: 8) {
                        Image(systemName: symbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(red: 1, green: 0.8, blue: 0.35))
                        Text(text)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(EditorColors.textSecondarySwift)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 1, green: 0.8, blue: 0.35).opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(Color(red: 1, green: 0.8, blue: 0.35).opacity(0.25), lineWidth: 0.5)
                            )
                    }
                }
            }
        )
    }

    private func propertyCell(property: ItemProperty, item: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(property.displayName)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(EditorColors.textTertiarySwift)
                if property.isRequired {
                    Text("*")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(EditorColors.accentSwift)
                }
                if let note = property.note {
                    Text("(\(note))")
                        .font(.system(size: 10))
                        .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.6))
                }
                // Info tooltip
                if let desc = property.description {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(EditorColors.textTertiarySwift.opacity(0.5))
                        .help(desc)
                }
            }
            control(for: property, item: item)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func control(for property: ItemProperty, item: [String: Any]) -> some View {
        switch property.type {
        case .text(let placeholder):
            TextField(placeholder, text: textBinding(property: property))
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(maxWidth: .infinity)
        case .integer(let placeholder):
            CommitNumberField(
                placeholder: placeholder,
                committedValue: intBinding(property: property)
            )
            .frame(maxWidth: .infinity)
        case .boolean:
            Toggle("", isOn: boolBinding(property: property))
                .toggleStyle(RibbonToggleStyle())
                .labelsHidden()
        case .selection(let options):
            RibbonSegmented(options: options, selection: selectionBinding(property: property))
                .frame(maxWidth: .infinity)
        case .stringList(let placeholder):
            StringListEditor(placeholder: placeholder, binding: stringListBinding(property: property))
        case .slider(let range, let step, let unit):
            RibbonSlider(range: range, step: step, unit: unit, binding: doubleBinding(property: property))
        case .filePicker(let allowedTypes):
            FilePickerField(allowedTypes: allowedTypes, binding: textBinding(property: property))
        case .colorPicker:
            ColorPickerField(binding: textBinding(property: property))
        }
    }

    // MARK: - Bindings

    private func textBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in (model?.selectedItem?[property.key] as? String) ?? "" },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }

    private func intBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return "" }
                if let n = m.selectedItem?[property.key] as? Int { return "\(n)" }
                if let n = m.selectedItem?[property.key] as? Double { return "\(Int(n))" }
                return ""
            },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }

    private func boolBinding(property: ItemProperty) -> Binding<Bool> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return true }
                if let b = m.selectedItem?[property.key] as? Bool { return b }
                if let s = m.selectedItem?[property.key] as? String { return s == "true" || s == "1" }
                return true
            },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }

    private func selectionBinding(property: ItemProperty) -> Binding<String> {
        Binding(
            get: { [weak model] in (model?.selectedItem?[property.key] as? String) ?? "" },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }

    private func stringListBinding(property: ItemProperty) -> Binding<[String]> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return [] }
                if let arr = m.selectedItem?[property.key] as? [String] { return arr }
                if let s = m.selectedItem?[property.key] as? String { return s.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                return []
            },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }

    private func doubleBinding(property: ItemProperty) -> Binding<Double> {
        Binding(
            get: { [weak model] in
                guard let m = model else { return 0 }
                if let n = m.selectedItem?[property.key] as? Double { return n }
                if let n = m.selectedItem?[property.key] as? Int { return Double(n) }
                return 0
            },
            set: { [weak model] v in model?.updateProperty(property.key, v) }
        )
    }
}

// MARK: - String List Editor (tag-style, for stock symbols etc.)

struct StringListEditor: View {
    let placeholder: String
    @Binding var binding: [String]
    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Tags
            if !binding.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(Array(binding.enumerated()), id: \.offset) { index, tag in
                        HStack(spacing: 3) {
                            Text(tag)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(EditorColors.textPrimarySwift)
                            Button(action: { binding.remove(at: index) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(EditorColors.textTertiarySwift)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(EditorColors.cardSwift)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                                )
                        }
                    }
                }
            }

            // Input
            HStack(spacing: 6) {
                TextField(placeholder, text: $inputText)
                    .textFieldStyle(RibbonTextFieldStyle())
                    .onSubmit { addTag() }
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(EditorColors.accentSwift)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addTag() {
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Support comma-separated batch add
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts where !part.isEmpty && !binding.contains(part) {
            binding.append(part)
        }
        inputText = ""
    }
}

// MARK: - Flow Layout (simple wrapping HStack)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x - spacing)
        }

        return (CGSize(width: totalWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Slider control

struct RibbonSlider: View {
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    @Binding var binding: Double

    var body: some View {
        HStack(spacing: 8) {
            Slider(value: $binding, in: range, step: step)
                .accentColor(EditorColors.accentSwift)
            Text("\(Int(binding))\(unit)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(EditorColors.textSecondarySwift)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

// MARK: - File picker field

struct FilePickerField: View {
    let allowedTypes: [String]
    @Binding var binding: String

    var body: some View {
        HStack(spacing: 6) {
            TextField(localized("选择文件...", "Choose file..."), text: $binding)
                .textFieldStyle(RibbonTextFieldStyle())
            Button(action: pickFile) {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(EditorColors.textSecondarySwift)
                    .frame(width: 28, height: 28)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(EditorColors.cardSwift)
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private func pickFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = allowedTypes.contains("folder")
        panel.allowsMultipleSelection = false
        if !allowedTypes.isEmpty && !allowedTypes.contains("folder") {
            panel.allowedContentTypes = allowedTypes.compactMap { UTType($0) }
        }
        if panel.runModal() == .OK, let url = panel.url {
            binding = url.path
        }
    }
}

// MARK: - Color picker field

struct ColorPickerField: View {
    @Binding var binding: String

    private var color: Color {
        Color(hex: binding) ?? .white
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                )
            TextField("#FFFFFF", text: $binding)
                .textFieldStyle(RibbonTextFieldStyle())
                .frame(maxWidth: 120)
        }
    }
}

// MARK: - Color hex extension

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}

// MARK: - Segmented control (fills width)

struct RibbonSegmented: View {
    let options: [String]
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isSelected = selection == option
                Button(action: { selection = option }) {
                    Text(option)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? Color.white : EditorColors.textSecondarySwift)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(EditorColors.accentSwift)
                                    .shadow(color: EditorColors.accentSwift.opacity(0.3), radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background {
            RoundedRectangle(cornerRadius: 9)
                .fill(EditorColors.cardSwift)
        }
    }
}

// MARK: - Toggle style

struct RibbonToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isOn ? EditorColors.accentSwift : EditorColors.cardSwift)
                    .frame(width: 32, height: 18)
                    .overlay(
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .offset(x: configuration.isOn ? 7 : -7)
                    )
                    .animation(.easeOut(duration: 0.15), value: configuration.isOn)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Text field style

struct RibbonTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(EditorColors.cardSwift)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(EditorColors.hairlineStrongSwift, lineWidth: 0.5)
                    )
            }
    }
}

// MARK: - Diagnostics

private func diagnose(_ item: [String: Any]) -> [(String, String)] {
    var issues: [(String, String)] = []
    let type = item["type"] as? String ?? "unknown"

    if ["staticButton", "escape"].contains(type) {
        let title = item["title"] as? String ?? ""
        if title.isEmpty {
            issues.append(("exclamationmark.triangle.fill", localized("缺少标题", "Missing title")))
        }
    }
    if let w = item["width"] as? Int {
        if w > 600 {
            issues.append(("arrowtriangle.right.and.line.vertical.and.arrowtriangle.left.fill",
                localized("宽度过大（\(w)px）", "Width too large (\(w)px)")))
        }
    }
    if type == "group" || type == "expandable" || type == "swipe" {
        let children = item["items"] as? [[String: Any]] ?? []
        if children.isEmpty {
            issues.append(("square.stack", localized("容器内无子项", "Container has no child items")))
        }
    }
    return issues
}
