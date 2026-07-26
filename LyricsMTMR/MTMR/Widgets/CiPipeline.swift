//
//  CiPipeline.swift  ·  item type: ciPipeline
//  CI/CD 流水线状态：读取 GitHub Actions 最近一次 workflow run 的结论（绿/红/进行中）。
//  需要在「设置 → 服务」里配置 GitHub Token；未配置时显示未配置并回退 mock。
//  属性：repo（owner/name）、refreshInterval。
//

import Cocoa

class CiPipelineItem: TBPollItem {
    private let repo: String
    private var state = "…"
    private var tint = TB.textSecondary
    private var configured = true

    init(identifier: NSTouchBarItem.Identifier, repo: String, refreshInterval: Double) {
        self.repo = repo
        super.init(identifier: identifier, refreshInterval: refreshInterval,
                   icon: "gearshape.2.fill", tint: TB.mint,
                   label: "CI", width: 138)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func compute() {
        let token = AppSettings.githubToken
        guard !token.isEmpty, !repo.isEmpty else {
            configured = false
            state = localized("未配置", "unset")
            tint = TB.textTertiary
            return
        }
        let url = "https://api.github.com/repos/\(repo)/actions/runs?per_page=1"
        guard let json = TBNet.json(url, headers: ["Authorization": "Bearer \(token)", "Accept": "application/vnd.github+json"]),
              let runs = (json as? [String: Any])?["workflow_runs"] as? [[String: Any]],
              let first = runs.first else {
            configured = true
            state = localized("无结果", "no runs")
            tint = TB.textTertiary
            return
        }
        configured = true
        let status = first["status"] as? String ?? ""
        let conclusion = first["conclusion"] as? String ?? ""
        if status != "completed" { state = localized("进行中", "running"); tint = TB.gold }
        else if conclusion == "success" { state = localized("通过", "pass"); tint = TB.mint }
        else { state = localized("失败", "fail"); tint = TB.coral }
    }

    override func apply() {
        metric.value = state
        metric.valueColor = configured ? tint : TB.textTertiary
        metric.iconTint = tint
        metric.subValue = configured ? nil : "GitHub"
    }
}
