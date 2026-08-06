//
//  GitStatus.swift  ·  item type: gitStatus
//  Git 仓库状态：bar 上始终显示「最近活动的仓库」——分支名 + 仓库名 ±脏文件数，
//  有领先/落后远端时追加 ↑n/↓n，像一条真正的状态行而不是计数器。
//  repoPath 本身是仓库时即该仓库；否则自动
//  扫描下一级子目录里的所有 git 仓库，按 .git/HEAD 修改时间排序取最近的。
//  点按展开两段式浮层：先列仓库，点选后给出操作行
//  （复制分支 / 复制路径 / 拉取 / 推送 / Finder 打开 / 终端打开 / 最新提交 / 返回列表）。
//  属性：repoPath（仓库或包含多个仓库的目录）、refreshInterval。
//
//  性能与健壮性设计：
//  - 仓库发现 = 纯文件系统扫描（.git 目录 / worktree 的 .git 文件），不启动 git 子进程；
//  - 分支名直接读 .git/HEAD，零进程开销；
//  - 脏文件计数仍走 git status --porcelain，但按仓库缓存最近成功值（15s TTL），
//    git 偶发卡顿/失败时沿用上次结果，组件不会闪烁或清空；
//  - 领先/落后（git status -sb）同样按仓库缓存（30s TTL），只读本端记录不联网；
//  - 目录瞬时不可读时保留上一次的仓库列表；
//  - 扫描结果瞬时为空时要求连续两次为空才真正清空，避免列表抖动；
//  - 多仓库浮层按 .git/HEAD 最近修改时间排序，常用仓库排在最前。
//

import Cocoa

class GitStatusItem: TBMetricPopoverItem {
    private struct Repo {
        let path: String
        let name: String
        let gitDir: String
        var branch: String
        var dirty: Int
        var ahead: Int
        var behind: Int
    }

    /// Dirty-count cache shared across polls: git status can be slow in big
    /// repos and transient failures must not blank the widget.
    private static var dirtyCache: [String: (count: Int, at: Date)] = [:]
    private static let dirtyCacheTTL: TimeInterval = 15
    /// Ahead/behind cache (git status -sb): local-only, never hits network.
    private static var abCache: [String: (ahead: Int, behind: Int, at: Date)] = [:]
    private static let abCacheTTL: TimeInterval = 30
    private static let cacheLock = NSLock()

    private let repoPath: String
    /// Consecutive empty scans; the repo list only clears after two in a row
    /// so a transient filesystem hiccup never blanks the widget.
    private var emptyStreak = 0
    /// Immutable scan result. `compute()` (background) builds a fresh one and
    /// swaps it under the lock; `apply()` / overlay code (main) only ever read
    /// copies, so there is no cross-queue data race.
    private struct Snapshot {
        var repos: [Repo] = []
        var configured = true
        var hasScanned = false
    }
    private var snapshot = Snapshot()
    private let snapshotLock = NSLock()
    /// The repo list currently shown in the overlay (kept stable across polls
    /// so button tags stay valid while the popover is open).
    private var overlayRepos: [Repo] = []
    private weak var resultLabel: NSTextField?
    /// Index of the repo currently shown in the overlay's action stage (nil = list stage).
    private var overlayRepoIndex: Int?

    init(identifier: NSTouchBarItem.Identifier, repoPath: String, refreshInterval: Double) {
        self.repoPath = (repoPath as NSString).expandingTildeInPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "arrow.triangle.branch", tint: TB.coral,
                   label: localized("仓库", "GIT"), width: 130)
        accent = TB.coral
    }
    required init?(coder: NSCoder) { return nil }

    // MARK: - Polling

    private func currentSnapshot() -> Snapshot {
        snapshotLock.lock()
        defer { snapshotLock.unlock() }
        return snapshot
    }

    private func commit(_ snap: Snapshot) {
        snapshotLock.lock()
        snapshot = snap
        snapshotLock.unlock()
    }

    override func compute() {
        var snap = Snapshot()
        guard !repoPath.isEmpty else {
            snap.configured = false
            snap.hasScanned = true
            commit(snap)
            return
        }
        if let gitDir = Self.gitDir(at: repoPath) {
            // 路径本身即仓库
            snap.repos = [Self.inspect(repoPath, gitDir: gitDir)]
            snap.hasScanned = true
            commit(snap)
            return
        }
        // 扫描一级子目录中的仓库（纯文件系统操作，不启动 git）
        let fm = FileManager.default
        var scanned = false
        var found: [Repo] = []
        if let entries = try? fm.contentsOfDirectory(atPath: repoPath) {
            scanned = true
            for entry in entries.sorted() where !entry.hasPrefix(".") {
                let sub = (repoPath as NSString).appendingPathComponent(entry)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: sub, isDirectory: &isDir), isDir.boolValue else { continue }
                guard let gitDir = Self.gitDir(at: sub) else { continue }
                found.append(Self.inspect(sub, gitDir: gitDir))
                if found.count >= 20 { break }
            }
        }
        // 目录瞬时不可读 → 保留上一次结果；扫描成功则即使为空也如实更新
        guard scanned else { return }
        // 防抖：连续两次空扫描才清空，避免瞬时抖动把仓库列表闪没
        if found.isEmpty {
            let previous = currentSnapshot()
            if !previous.repos.isEmpty && emptyStreak == 0 {
                emptyStreak += 1
                return
            }
        }
        emptyStreak = 0
        snap.repos = found.sorted { Self.headMTime($0.gitDir) > Self.headMTime($1.gitDir) }
        snap.hasScanned = true
        commit(snap)
    }

    override func apply() {
        let snap = currentSnapshot()
        guard snap.configured else {
            metric.value = localized("未配置", "unset")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
            return
        }
        guard snap.hasScanned else {
            metric.value = localized("扫描中…", "scanning…")
            metric.valueColor = TB.textSecondary
            metric.subValue = nil
            metric.iconTint = TB.textSecondary
            return
        }
        guard let active = snap.repos.first else {
            metric.value = localized("无仓库", "no repos")
            metric.valueColor = TB.textTertiary
            metric.subValue = nil
            metric.iconTint = TB.textTertiary
            return
        }
        // Status line, not a counter: branch of the most recently active
        // repo up front, its name (plus dirty badge and repo total) behind.
        metric.value = active.branch
        metric.valueColor = TB.textPrimary
        var sub = active.name
        if active.dirty > 0 { sub += " ±\(active.dirty)" }
        if active.ahead > 0 { sub += " ↑\(active.ahead)" }
        if active.behind > 0 { sub += " ↓\(active.behind)" }
        if snap.repos.count > 1 { sub += " · \(snap.repos.count)" }
        metric.subValue = sub
        metric.iconTint = active.dirty > 0 ? TB.gold : TB.mint
    }

    // MARK: - Overlay

    override func buildOverlay() -> NSView {
        overlayRepoIndex = nil
        return buildListOverlay()
    }

    private func buildListOverlay() -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.coral)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        let snap = currentSnapshot()
        overlayRepos = snap.repos
        guard !snap.repos.isEmpty else {
            resultLabel = TBOverlay.resultLabel(in: card,
                text: snap.configured ? (snap.hasScanned ? localized("未发现 Git 仓库", "no repos found") : localized("正在扫描仓库…", "scanning…")) : localized("未配置仓库路径", "repo path unset"),
                tint: TB.textSecondary)
            return root
        }
        resultLabel = TBOverlay.resultLabel(in: card, text: localized("点选仓库展开操作", "tap a repo for actions"), tint: TB.textSecondary)
        let buttons = snap.repos.prefix(7).enumerated().map { index, repo -> NSButton in
            let title = repo.dirty > 0 ? "\(repo.name) ±\(repo.dirty)" : repo.name
            return TBOverlay.pillButton(title: title, tag: index, target: self, action: #selector(pick(_:)),
                                        tint: repo.dirty > 0 ? TB.gold : TB.mint)
        }
        TBOverlay.buttonRow(in: card, buttons: Array(buttons), afterClose: close)
        return root
    }

    /// Action stage for one selected repo.
    private func buildActionsOverlay(_ repo: Repo) -> NSView {
        let root = TBOverlay.rootView()
        let card = TBOverlay.card(in: root, widthRatio: 0.97, accent: TB.coral)
        let close = TBOverlay.closeButton(in: card, target: self, action: #selector(closeOverlay))
        var badges = ""
        if repo.dirty > 0 { badges += " ±\(repo.dirty)" }
        if repo.ahead > 0 { badges += " ↑\(repo.ahead)" }
        if repo.behind > 0 { badges += " ↓\(repo.behind)" }
        resultLabel = TBOverlay.resultLabel(in: card,
            text: "\(repo.name) · \(repo.branch)\(badges)",
            tint: TB.textPrimary)
        let copyBranch = TBOverlay.pillButton(title: localized("复制分支", "Branch"), tag: 0, target: self, action: #selector(act(_:)), tint: TB.mint)
        let copyPath = TBOverlay.pillButton(title: localized("复制路径", "Path"), tag: 1, target: self, action: #selector(act(_:)), tint: TB.sky)
        let finder = TBOverlay.pillButton(title: "Finder", tag: 2, target: self, action: #selector(act(_:)), tint: TB.gold)
        let terminal = TBOverlay.pillButton(title: localized("终端", "Term"), tag: 3, target: self, action: #selector(act(_:)), tint: TB.purple)
        let back = TBOverlay.pillButton(title: localized("← 返回", "Back"), tag: 4, target: self, action: #selector(backToList(_:)), tint: TB.textSecondary)
        let lastCommit = TBOverlay.pillButton(title: localized("最新提交", "Commit"), tag: 5, target: self, action: #selector(act(_:)), tint: TB.gold)
        let pull = TBOverlay.pillButton(title: localized("拉取", "Pull"), tag: 6, target: self, action: #selector(act(_:)), tint: TB.sky)
        let push = TBOverlay.pillButton(title: localized("推送", "Push"), tag: 7, target: self, action: #selector(act(_:)), tint: TB.mint)
        TBOverlay.buttonRow(in: card, buttons: [copyBranch, copyPath, pull, push, lastCommit, finder, terminal, back], afterClose: close)
        return root
    }

    /// Swap the overlay content in place (the popover stays presented).
    private func refreshOverlay(with view: NSView) {
        fullViewItem?.view = view
    }

    @objc private func pick(_ sender: NSButton) {
        guard sender.tag < overlayRepos.count else { return }
        HapticFeedback.instance.tap(type: .medium)
        overlayRepoIndex = sender.tag
        refreshOverlay(with: buildActionsOverlay(overlayRepos[sender.tag]))
    }

    @objc private func backToList(_ sender: NSButton) {
        HapticFeedback.instance.tap(type: .back)
        overlayRepoIndex = nil
        refreshOverlay(with: buildListOverlay())
    }

    @objc private func act(_ sender: NSButton) {
        guard let index = overlayRepoIndex, index < overlayRepos.count else { return }
        let repo = overlayRepos[index]
        HapticFeedback.instance.tap(type: .medium)
        switch sender.tag {
        case 0:
            TBClip.write(repo.branch)
            resultLabel?.stringValue = localized("已复制分支：\(repo.branch)", "branch copied")
            resultLabel?.textColor = TB.mint
        case 1:
            TBClip.write(repo.path)
            resultLabel?.stringValue = localized("已复制路径", "path copied")
            resultLabel?.textColor = TB.mint
        case 2:
            resultLabel?.stringValue = localized("Finder 打开中…", "opening Finder…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                _ = TBShell.run("open \(Self.shellQuote(repo.path))", timeout: 5)
                DispatchQueue.main.async { [weak self] in
                    self?.resultLabel?.stringValue = localized("已在 Finder 打开", "opened in Finder")
                    self?.resultLabel?.textColor = TB.mint
                }
            }
        case 3:
            resultLabel?.stringValue = localized("终端打开中…", "opening Terminal…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                _ = TBShell.run("open -a Terminal \(Self.shellQuote(repo.path))", timeout: 5)
                DispatchQueue.main.async { [weak self] in
                    self?.resultLabel?.stringValue = localized("已在终端打开", "opened in Terminal")
                    self?.resultLabel?.textColor = TB.mint
                }
            }
        case 5:
            // 最新提交：短哈希 + 标题，展示并复制
            resultLabel?.stringValue = localized("读取提交中…", "loading commit…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                let out = TBShell.run("git -C \(Self.shellQuote(repo.path)) log -1 --pretty=%h\\ %s 2>/dev/null", timeout: 6)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if out.isEmpty {
                        self.resultLabel?.stringValue = localized("无提交记录", "no commits")
                        self.resultLabel?.textColor = TB.textTertiary
                    } else {
                        TBClip.write(out)
                        self.resultLabel?.stringValue = localized("已复制：\(out)", "copied: \(out)")
                        self.resultLabel?.textColor = TB.gold
                    }
                }
            }
        case 6:
            // 拉取：--ff-only 只做快进合并，不会在 Touch Bar 上触发 merge 提交
            resultLabel?.stringValue = localized("拉取中…", "pulling…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                let out = TBShell.run("git -C \(Self.shellQuote(repo.path)) pull --ff-only 2>&1", timeout: 30)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    Self.invalidateCaches(repo.path)
                    self.resultLabel?.textColor = out.contains("fatal") || out.contains("error") ? TB.coral : TB.mint
                    self.resultLabel?.stringValue = Self.pullSummary(out)
                }
            }
        case 7:
            resultLabel?.stringValue = localized("推送中…", "pushing…")
            resultLabel?.textColor = TB.textSecondary
            DispatchQueue.global().async { [weak self] in
                let out = TBShell.run("git -C \(Self.shellQuote(repo.path)) push 2>&1", timeout: 30)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    Self.invalidateCaches(repo.path)
                    self.resultLabel?.textColor = out.contains("fatal") || out.contains("error") ? TB.coral : TB.mint
                    self.resultLabel?.stringValue = Self.pushSummary(out)
                }
            }
        default:
            break
        }
    }

    private static func pullSummary(_ out: String) -> String {
        if out.contains("Already up to date") || out.contains("已经是最新的") {
            return localized("已是最新 ✓", "already up to date")
        }
        if out.contains("Fast-forward") || out.contains("快进") {
            return localized("已快进更新 ✓", "fast-forwarded")
        }
        if out.contains("fatal") || out.contains("error") {
            let line = out.split(separator: "\n").last.map(String.init) ?? out
            return localized("拉取失败：\(String(line.suffix(30)))", "pull failed")
        }
        return localized("已更新 ✓", "updated")
    }

    private static func pushSummary(_ out: String) -> String {
        if out.contains("Everything up-to-date") || out.contains("一切都是最新的") {
            return localized("远端已是最新 ✓", "remote up to date")
        }
        if out.contains("fatal") || out.contains("error") {
            let line = out.split(separator: "\n").last.map(String.init) ?? out
            return localized("推送失败：\(String(line.suffix(30)))", "push failed")
        }
        if out.contains("->") {
            return localized("已推送 ✓", "pushed")
        }
        return localized("推送完成 ✓", "pushed")
    }

    /// Pull/push change both dirty count and ahead/behind — drop the caches so
    /// the next poll shows fresh numbers instead of stale ones for up to 30s.
    private static func invalidateCaches(_ path: String) {
        cacheLock.lock()
        dirtyCache.removeValue(forKey: path)
        abCache.removeValue(forKey: path)
        cacheLock.unlock()
    }

    // MARK: - Git helpers (filesystem-first, no subprocess for discovery)

    private static func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Resolves the real .git directory for a repo path; supports worktrees,
    /// where `.git` is a plain file containing `gitdir: <path>`.
    private static func gitDir(at path: String) -> String? {
        let fm = FileManager.default
        let entry = (path as NSString).appendingPathComponent(".git")
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: entry, isDirectory: &isDir) else { return nil }
        if isDir.boolValue { return entry }
        if let content = try? String(contentsOfFile: entry, encoding: .utf8) {
            let line = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("gitdir:") {
                var target = String(line.dropFirst("gitdir:".count)).trimmingCharacters(in: .whitespaces)
                if !(target as NSString).isAbsolutePath {
                    target = (path as NSString).appendingPathComponent(target)
                }
                return fm.fileExists(atPath: target) ? target : nil
            }
        }
        return nil
    }

    /// Branch name straight from .git/HEAD (`ref: refs/heads/<branch>`);
    /// a detached HEAD shows the short commit hash.
    private static func branch(inGitDir gitDir: String) -> String {
        let headPath = (gitDir as NSString).appendingPathComponent("HEAD")
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8) else { return "?" }
        let line = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("ref:") {
            let ref = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            let prefix = "refs/heads/"
            return ref.hasPrefix(prefix) ? String(ref.dropFirst(prefix.count)) : ref
        }
        return String(line.prefix(7))
    }

    private static func headMTime(_ gitDir: String) -> Date {
        let headPath = (gitDir as NSString).appendingPathComponent("HEAD")
        let attrs = try? FileManager.default.attributesOfItem(atPath: headPath)
        return (attrs?[.modificationDate] as? Date) ?? .distantPast
    }

    /// Dirty file count via `git status --porcelain`, cached per repo.
    /// A trailing `___RC:<code>` marker distinguishes a real "0 changes"
    /// from a failed/timed-out git invocation.
    private static func dirtyCount(at path: String) -> Int {
        cacheLock.lock()
        if let cached = dirtyCache[path], Date().timeIntervalSince(cached.at) < dirtyCacheTTL {
            cacheLock.unlock()
            return cached.count
        }
        cacheLock.unlock()

        let command = "set -o pipefail; git -C \(shellQuote(path)) status --porcelain 2>/dev/null | wc -l; printf '___RC:%s' $?"
        let out = TBShell.run(command, timeout: 6)
        var count: Int?
        if let marker = out.range(of: "___RC:0") {
            count = Int(out[..<marker.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines))
        }

        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let count = count {
            dirtyCache[path] = (count, Date())
            return count
        }
        // Transient failure (git hiccup / timeout): keep the last good value.
        return dirtyCache[path]?.count ?? 0
    }

    /// Ahead/behind the upstream, parsed from the first line of
    /// `git status -sb` ("## main...origin/main [ahead 2, behind 1]").
    /// Purely local — git reports the last known remote ref without fetching.
    private static func aheadBehind(at path: String) -> (ahead: Int, behind: Int) {
        cacheLock.lock()
        if let cached = abCache[path], Date().timeIntervalSince(cached.at) < abCacheTTL {
            cacheLock.unlock()
            return (cached.ahead, cached.behind)
        }
        cacheLock.unlock()

        let command = "set -o pipefail; git -C \(shellQuote(path)) status -sb --porcelain 2>/dev/null | head -1; printf '___RC:%s' $?"
        let out = TBShell.run(command, timeout: 6)
        var result: (ahead: Int, behind: Int)?
        if let marker = out.range(of: "___RC:0") {
            let line = String(out[..<marker.lowerBound])
                .split(separator: "\n").first.map(String.init) ?? ""
            var ahead = 0
            var behind = 0
            if let lb = line.range(of: "["), let rb = line.range(of: "]", options: .backwards) {
                for part in line[lb.upperBound..<rb.lowerBound].split(separator: ",") {
                    let kv = part.trimmingCharacters(in: .whitespaces).split(separator: " ")
                    guard kv.count == 2, let n = Int(kv[1]) else { continue }
                    if kv[0] == "ahead" { ahead = n } else if kv[0] == "behind" { behind = n }
                }
            }
            result = (ahead, behind)
        }

        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let result = result {
            abCache[path] = (result.ahead, result.behind, Date())
            return result
        }
        // Transient failure: keep the last good value.
        let fallback = abCache[path]
        return (fallback?.ahead ?? 0, fallback?.behind ?? 0)
    }

    private static func inspect(_ path: String, gitDir: String) -> Repo {
        let ab = aheadBehind(at: path)
        return Repo(path: path,
                    name: (path as NSString).lastPathComponent,
                    gitDir: gitDir,
                    branch: branch(inGitDir: gitDir),
                    dirty: dirtyCount(at: path),
                    ahead: ab.ahead,
                    behind: ab.behind)
    }
}
