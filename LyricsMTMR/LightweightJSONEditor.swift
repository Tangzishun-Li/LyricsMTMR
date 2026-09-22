// LightweightJSONEditor.swift
//  轻量级 JSON 编辑器 —— 仅检查括号闭合，按需加载
//  当用户从文件夹打开 JSON 文件时显示，关闭后不占用内存

import Cocoa
import SwiftUI

// MARK: - 编辑器窗口控制器

/// 轻量级 JSON 编辑器窗口控制器
/// 仅在打开文件时创建，关闭后自动释放
final class LightweightJSONEditorWindowController: NSWindowController {
    
    private let filePath: String
    private var textView: JSONBracketMatchingTextView!
    
    init(filePath: String) {
        self.filePath = filePath
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = (filePath as NSString).lastPathComponent
        window.center()
        window.minSize = NSSize(width: 400, height: 300)
        
        super.init(window: window)
        
        setupUI()
        loadFile()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = window else { return }
        
        // 创建滚动视图
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        
        // 创建文本视图（带括号匹配）
        textView = JSONBracketMatchingTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // 设置行号视图
        let lineNumberView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        lineNumberView.clientView = textView
        scrollView.verticalRulerView = lineNumberView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        
        scrollView.documentView = textView
        window.contentView = scrollView
        
        // 工具栏
        setupToolbar()
    }
    
    private func setupToolbar() {
        guard let window = window else { return }
        
        let toolbar = NSToolbar(identifier: "JSONEditorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
    }
    
    private func loadFile() {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            showAlert(message: "无法读取文件", informativeText: "文件可能不存在或没有读取权限。")
            return
        }
        
        textView.string = content
        
        // 初始检查括号
        checkBrackets()
    }
    
    private func saveFile() {
        do {
            try textView.string.write(toFile: filePath, atomically: true, encoding: .utf8)
        } catch {
            showAlert(message: "保存失败", informativeText: error.localizedDescription)
        }
    }
    
    private func checkBrackets() {
        let isValid = textView.validateBrackets()
        updateBracketStatus(isValid: isValid)
    }
    
    private func updateBracketStatus(isValid: Bool) {
        // 更新窗口标题显示括号状态
        let fileName = (filePath as NSString).lastPathComponent
        window?.title = isValid ? fileName : "\(fileName) ⚠️ 括号不匹配"
    }
    
    private func showAlert(message: String, informativeText: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

// MARK: - NSToolbarDelegate

extension LightweightJSONEditorWindowController: NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.saveItem, .flexibleSpace, .validateItem]
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.saveItem, .flexibleSpace, .validateItem]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .saveItem:
            let item = NSToolbarItem(itemIdentifier: .saveItem)
            item.label = "保存"
            item.toolTip = "保存文件 (⌘S)"
            item.image = NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "保存")
            item.target = self
            item.action = #selector(saveAction)
            return item
        case .validateItem:
            let item = NSToolbarItem(itemIdentifier: .validateItem)
            item.label = "检查括号"
            item.toolTip = "检查括号是否闭合"
            item.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "检查")
            item.target = self
            item.action = #selector(validateAction)
            return item
        default:
            return nil
        }
    }
    
    @objc private func saveAction() {
        saveFile()
    }
    
    @objc private func validateAction() {
        checkBrackets()
    }
}

// MARK: - NSToolbarItem.Identifier 扩展

private extension NSToolbarItem.Identifier {
    static let saveItem = NSToolbarItem.Identifier("com.lyricsmtmr.jsoneditor.save")
    static let validateItem = NSToolbarItem.Identifier("com.lyricsmtmr.jsoneditor.validate")
}

// MARK: - 带括号匹配的文本视图

/// 搜索方向枚举
private enum SearchDirection {
    case backward
    case forward
}

/// 自定义 NSTextView，实现括号匹配和高亮
final class JSONBracketMatchingTextView: NSTextView {
    
    /// 括号对定义
    private let bracketPairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}"
    ]
    
    private var matchingBracketRanges: [NSRange] = []
    
    override func keyDown(with event: NSEvent) {
        // 处理括号自动补全
        if let char = event.characters?.first {
            if let closing = bracketPairs[char] {
                // 输入左括号时自动补全右括号
                insertText(String(char), replacementRange: selectedRange())
                let insertionPoint = selectedRange().location
                insertText(String(closing), replacementRange: NSRange(location: insertionPoint, length: 0))
                setSelectedRange(NSRange(location: insertionPoint, length: 0))
                
                // 高亮匹配的括号
                highlightMatchingBrackets()
                return
            }
        }
        
        super.keyDown(with: event)
        
        // 光标移动时检查括号匹配
        highlightMatchingBrackets()
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        highlightMatchingBrackets()
    }
    
    /// 高亮匹配的括号
    private func highlightMatchingBrackets() {
        // 清除之前的高亮
        clearBracketHighlights()
        
        let text = string as NSString
        let cursorLocation = selectedRange().location
        
        guard cursorLocation > 0 && cursorLocation <= text.length else { return }
        
        // 检查光标前的字符
        let charBeforeCursor = text.character(at: cursorLocation - 1)
        let char = Character(UnicodeScalar(charBeforeCursor)!)
        
        // 如果是右括号，找匹配的左括号
        if bracketPairs.values.contains(char) {
            if let matchLocation = findMatchingBracket(for: char, at: cursorLocation - 1, direction: .backward) {
                highlightBracket(at: cursorLocation - 1)
                highlightBracket(at: matchLocation)
            }
        }
        // 如果是左括号，找匹配的右括号
        else if bracketPairs.keys.contains(char) {
            if let matchLocation = findMatchingBracket(for: char, at: cursorLocation - 1, direction: .forward) {
                highlightBracket(at: cursorLocation - 1)
                highlightBracket(at: matchLocation)
            }
        }
    }
    
    /// 查找匹配的括号
    private func findMatchingBracket(for bracket: Character, at location: Int, direction: SearchDirection) -> Int? {
        let text = string as NSString
        let opening: Character
        let closing: Character
        
        if direction == .backward {
            opening = bracket
            closing = bracketPairs[bracket]!
        } else {
            closing = bracket
            opening = bracketPairs.first(where: { $0.value == bracket })!.key
        }
        
        var depth = 1
        var current = location
        
        while true {
            if direction == .backward {
                current -= 1
                guard current >= 0 else { return nil }
            } else {
                current += 1
                guard current < text.length else { return nil }
            }
            
            let char = Character(UnicodeScalar(text.character(at: current))!)
            
            if char == opening {
                depth -= 1
                if depth == 0 {
                    return current
                }
            } else if char == closing {
                depth += 1
            }
        }
    }
    
    /// 高亮指定位置的括号
    private func highlightBracket(at location: Int) {
        let range = NSRange(location: location, length: 1)
        textStorage?.addAttribute(.backgroundColor, value: NSColor.systemYellow.withAlphaComponent(0.3), range: range)
        matchingBracketRanges.append(range)
    }
    
    /// 清除括号高亮
    private func clearBracketHighlights() {
        for range in matchingBracketRanges {
            textStorage?.removeAttribute(.backgroundColor, range: range)
        }
        matchingBracketRanges.removeAll()
    }
    
    /// 验证所有括号是否闭合
    func validateBrackets() -> Bool {
        let text = string as NSString
        var stack: [(Character, Int)] = []
        
        for i in 0..<text.length {
            let char = Character(UnicodeScalar(text.character(at: i))!)
            
            if bracketPairs.keys.contains(char) {
                stack.append((char, i))
            } else if let opening = bracketPairs.first(where: { $0.value == char })?.key {
                guard let last = stack.last, last.0 == opening else {
                    // 括号不匹配
                    highlightError(at: i)
                    return false
                }
                stack.removeLast()
            }
        }
        
        if !stack.isEmpty {
            // 有未闭合的括号
            highlightError(at: stack.last!.1)
            return false
        }
        
        return true
    }
    
    /// 高亮错误位置
    private func highlightError(at location: Int) {
        let range = NSRange(location: location, length: 1)
        textStorage?.addAttribute(.backgroundColor, value: NSColor.systemRed.withAlphaComponent(0.3), range: range)
        
        // 3秒后自动清除
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.textStorage?.removeAttribute(.backgroundColor, range: range)
        }
    }
}

// MARK: - 行号视图

/// 行号标尺视图
final class LineNumberRulerView: NSRulerView {
    
    private let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    
    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        ruleThickness = 40
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let textView = clientView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }
        
        // 绘制背景
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()
        
        let text = textView.string as NSString
        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        
        var lineNumber = 1
        var previousY: CGFloat = -1
        
        // 绘制每一行的行号
        for i in 0..<characterRange.length {
            let charIndex = characterRange.location + i
            let lineRange = text.lineRange(for: NSRange(location: charIndex, length: 0))
            
            guard lineRange.location == charIndex else { continue }
            
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = lineRect.origin.y + textView.textContainerInset.height
            
            guard y != previousY else { continue }
            previousY = y
            
            let lineNumberString = "\(lineNumber)" as NSString
            let size = lineNumberString.size(withAttributes: [.font: font])
            let x = ruleThickness - size.width - 5
            
            lineNumberString.draw(at: NSPoint(x: x, y: y), withAttributes: [
                .font: font,
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            
            lineNumber += 1
        }
    }
}

// MARK: - SwiftUI 包装器（用于在 SwiftUI 中使用）

/// SwiftUI 包装器，用于在 SwiftUI 视图中嵌入编辑器
struct LightweightJSONEditorView: NSViewRepresentable {
    let filePath: String
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        
        let textView = JSONBracketMatchingTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        // 加载文件内容
        if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            textView.string = content
        }
        
        scrollView.documentView = textView
        
        // 添加行号
        let lineNumberView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
        lineNumberView.clientView = textView
        scrollView.verticalRulerView = lineNumberView
        scrollView.rulersVisible = true
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // 可以在这里处理更新
    }
}

// MARK: - 便捷扩展

extension NSWorkspace {
    /// 使用内置轻量级编辑器打开 JSON 文件
    func openJSONFileWithLightweightEditor(_ filePath: String) {
        let controller = LightweightJSONEditorWindowController(filePath: filePath)
        controller.showWindow(nil)
        
        // 保持控制器的强引用，直到窗口关闭
        objc_setAssociatedObject(controller.window!, "editorController", controller, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}