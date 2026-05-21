//
//  JSONEditorController.swift
//  LyricsMTMR
//
//  Lightweight JSON editor for MTMR configuration.
//  This source code is licensed under MIT.
//  See LICENSE file in the project root for full license information.
//

import Cocoa

class JSONEditorController: NSWindowController {
    private let textView: NSTextView = {
        let tv = NSTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tv.textColor = NSColor.textColor
        tv.backgroundColor = NSColor.textBackgroundColor
        tv.autoresizingMask = [.width, .height]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width, .height]
        tv.textContainer?.widthTracksTextView = true
        return tv
    }()

    private let statusLabel: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.secondaryLabelColor
        label.alignment = .center
        return label
    }()

    private var currentFilePath: String?

    private let saveButton: NSButton = {
        let btn = NSButton(title: "Save", target: nil, action: nil)
        btn.bezelStyle = .rounded
        btn.keyEquivalent = "\r"
        return btn
    }()

    private let reloadButton: NSButton = {
        let btn = NSButton(title: "Reload", target: nil, action: nil)
        btn.bezelStyle = .rounded
        return btn
    }()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "JSON Configuration Editor"
        window.minSize = NSSize(width: 400, height: 300)

        let appSupportDir = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!.appending("/LyricsMTMR")
        let filePath = appSupportDir.appending("/items.json")

        self.init(window: window)
        currentFilePath = filePath
        setupUI(window: window)
        loadFile()
    }

    private func setupUI(window: NSWindow) {
        let contentView = window.contentView!

        let scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let buttonBar = NSStackView(views: [saveButton, reloadButton, statusLabel])
        buttonBar.orientation = .horizontal
        buttonBar.spacing = 8
        buttonBar.alignment = .centerY
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.distribution = .fill

        saveButton.target = self
        saveButton.action = #selector(saveFile)

        reloadButton.target = self
        reloadButton.action = #selector(reloadConfig)

        contentView.addSubview(scrollView)
        contentView.addSubview(buttonBar)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            buttonBar.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            buttonBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            buttonBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            buttonBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            statusLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
        ])

        textView.textContainerInset = NSSize(width: 8, height: 8)
    }

    private func loadFile() {
        guard let path = currentFilePath else {
            statusLabel.stringValue = "No file path configured"
            return
        }

        if FileManager.default.fileExists(atPath: path) {
            if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                textView.string = content
                statusLabel.stringValue = "Loaded: \(path)"
            } else {
                textView.string = "// Error loading file"
                statusLabel.stringValue = "Error loading file"
            }
        } else {
            textView.string = "// Configuration file not found at:\n// \(path)\n// Create a new configuration or use the default."
            statusLabel.stringValue = "File not found"
        }
    }

    @objc private func saveFile() {
        guard let path = currentFilePath else {
            statusLabel.stringValue = "No file path configured"
            return
        }

        do {
            try textView.string.write(toFile: path, atomically: true, encoding: .utf8)
            statusLabel.stringValue = "Saved successfully"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.statusLabel.stringValue = "Saved: \(path)"
            }
        } catch {
            statusLabel.stringValue = "Save failed: \(error.localizedDescription)"
        }
    }

    @objc private func reloadConfig() {
        TouchBarController.shared.reloadStandardConfig()
        statusLabel.stringValue = "Configuration reloaded"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.updateStatusAfterReload()
        }
    }

    private func updateStatusAfterReload() {
        if let path = currentFilePath {
            statusLabel.stringValue = "Loaded: \(path)"
        }
    }
}
