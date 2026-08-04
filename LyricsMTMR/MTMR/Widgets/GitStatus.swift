//
//  GitStatus.swift  ·  item type: gitStatus
//  Git 仓库状态：repoPath 本身是仓库时显示分支名与脏文件数；
//  不是仓库时自动扫描下一级子目录里的所有 git 仓库，汇总「仓库数 / 有变更数」，
//  点按展开浮层逐个列出（点选即复制该仓库的分支名）。
//  属性：repoPath（仓库或包含多个仓库的目录）、refreshInterval。
//

import Cocoa

class GitStatusItem: TBMetricPopoverItem {
    private struct Repo {
        let path: String
        let name: String
        var branch: String
        var dirty: Int
    }

    private let repoPath: String
    private var repos: [Repo] = []
    private var isRepo = false
    private var configured = true
    private weak var resultLabel: NSTextField?

    init(identifier: NSTouchBarItem.Identifier, repoPath: String, refreshInterval: Double) {
        self.repoPath = (repoPath as NSString).expandingTildeInPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "arrow.triangle.branch", tint: TB.coral,
                   label: localized("仓库", "GIT"), width: 130)
        accent = TB.coral
    }
    required init?(coder: NSCoder) { return nil }

    // MARK: - Polling

    override func compute() {
        guard !repoPath.isEmpty else {
            configured = false
            repos = []
            return
        }
        configured = true
        var found: [Repo] = []
        if Self.gitBranch(at: repoPath) != nil {
            // 路径本身即仓库
            isRepo = true
            found.append(Self.inspect(repoPath))
        } else {
            // 扫描一级子目录中的仓库
            isRepo = false
            let fm = FileManager.default
            if let entries = try? fm.contentsOfDirectory(atPath: repoPath) {
                for entry in entries.sorted() where !entry.hasPrefix(".") {
                    let sub = (repoPath as NSString).appendingPathComponent(entry)
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue else { continue }
                    if Self.gitBranch(at: sub) != nil {
                        found.append(Self.inspect(sub))
                    }
                    if found.count >= 20 { break }
                }
            }
        }
        repos = found
    }

    override func apply() {
        guard configured else {
            metric.value = localized("未配置", "unset")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
            return
        }
        if isRepo, let repo = repos.first {
            metric.value = repo.branch
            metric.valueColor = TB.textPrimary
            metric.subValue = repo.dirty > 0 ? "±\(repo.dirty)" : "✓"
            metric.iconTint = repo.dirty > 0 ? TB.gold : TB.mint
        } else if repos.isEmpty {
            metric.value = localized("无仓库", "no repos")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
        } else {
            let dirtyCount = repos.filter { $0.dirty > 0 }.count
            metric.value = "\(repos.count)\(localized(" 仓库", " repos"))"
            metric.valueColor = TB.textPrimary
            metric.subValue = dirtyCount > 0 ? "\(dirtyCount)±" : "✓"
            metric.iconTint = dirtyCount > 0 ? TB.gold : TB.mint
        }
    }

    // MARK: - Overlay

    override func buildOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.coral)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        guard !repos.isEmpty else {
            resultLabel = TBOverlay.resultLabel(in: card,
                text: configured ? localized("未发现 Git 仓库", "no repos found") : localized("未配置仓库路径", "repo path unset"),
                tint: TB.textSecondary)
            return root
        }
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选仓库复制分支名", "tap to copy branch"), tint: TB.textSecondary)
        let buttons = repos.prefix(7).enumerated().map { index, repo -> NSButton in
            let title = repo.dirty > 0 ? "\(repo.name) ±\(repo.dirty)" : repo.name
            return TBOverlay.pillButton(title: title, tag: index, target: self, action: #selector(pick(_:)),
                                        tint: repo.dirty > 0 ? TB.gold : TB.mint)
        }
        TBOverlay.buttonRow(in: card, buttons: Array(buttons), afterClose: close)
        return root
    }

    @objc private func pick(_ sender: NSButton) {
        guard sender.tag < repos.count else { return }
        let repo = repos[sender.tag]
        HapticFeedback.instance.tap(type: .medium)
        TBClip.write(repo.branch)
        let extra = repos.count > 7 ? localized(" · 共 \(repos.count) 个", " · \(repos.count) total") : ""
        resultLabel?.stringValue = "\(repo.name) · \(repo.branch)\(repo.dirty > 0 ? " ±\(repo.dirty)" : "")\(extra)"
        resultLabel?.textColor = TB.mint
    }

    // MARK: - Git helpers

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func gitBranch(at path: String) -> String? {
        let out = TBShell.run("git -C \(shellQuote(path)) rev-parse --abbrev-ref HEAD 2>/dev/null", timeout: 5)
        return out.isEmpty ? nil : out
    }

    private static func inspect(_ path: String) -> Repo {
        let branch = gitBranch(at: path) ?? "?"
        let status = TBShell.run("git -C \(shellQuote(path)) status --porcelain 2>/dev/null | wc -l", timeout: 6)
        let dirty = Int(status.trimmingCharacters(in: .whitespaces)) ?? 0
        return Repo(path: path, name: (path as NSString).lastPathComponent, branch: branch, dirty: dirty)
    }
}
