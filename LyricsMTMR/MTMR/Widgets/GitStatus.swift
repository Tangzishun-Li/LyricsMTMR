//
//  GitStatus.swift  ·  item type: gitStatus
//  Git 仓库状态：显示当前分支名与脏文件数量（未提交变更）。
//  通过 `git rev-parse` / `git status --porcelain` 读取，后台刷新。
//  属性：repoPath（仓库路径，留空显示未配置）、refreshInterval。
//

import Cocoa

class GitStatusItem: TBPollItem {
    private let repoPath: String
    private var branch = "…"
    private var dirty = 0
    private var configured = true

    init(identifier: NSTouchBarItem.Identifier, repoPath: String, refreshInterval: Double) {
        self.repoPath = (repoPath as NSString).expandingTildeInPath
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "arrow.triangle.branch", tint: TB.coral,
                   label: localized("仓库", "GIT"), width: 130)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        guard !repoPath.isEmpty else {
            configured = false
            branch = localized("未配置", "unset")
            dirty = 0
            return
        }
        let branchOut = TBShell.run("git -C '\(repoPath)' rev-parse --abbrev-ref HEAD 2>/dev/null")
        if branchOut.isEmpty {
            configured = false
            branch = localized("非仓库", "n/a")
            dirty = 0
            return
        }
        configured = true
        branch = branchOut
        let status = TBShell.run("git -C '\(repoPath)' status --porcelain 2>/dev/null | wc -l")
        dirty = Int(status.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    override func apply() {
        metric.value = branch
        metric.valueColor = configured ? TB.textPrimary : TB.textTertiary
        metric.subValue = dirty > 0 ? "±\(dirty)" : "✓"
        metric.iconTint = dirty > 0 ? TB.gold : TB.mint
    }
}
