import Foundation

class AppleScriptTouchBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private var script: NSAppleScript!
    private let interval: TimeInterval
    private var forceHideConstraint: NSLayoutConstraint!
    private let alternativeImages: [String: SourceProtocol]
    /// R60-a：脚本原文快照（deferred 放行时从文本重建 NSAppleScript；
    /// filePath 型 source 经 string/fileString 兜底，取不到则按无脚本处理）。
    private let sourceText: String?

    /// round 24 收官审计：隐藏暂停门。AppleScript 自循环与 bar 显隐零关联
    /// ——隐藏期仍按 interval 执行用户脚本（任意开销）；本卡纳入暂停：
    /// 隐藏期链在下一 hop 终结，恢复时立即补刷一次 + 按原节奏继续
    /// （同 ShellScriptTouchBarItem / MusicBarItem 模式）。
    /// round 23 播种：隐藏期重建时 init 的首次执行被 guard 拦截。
    private let pauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    /// R60-a 启动 TCC 弹窗防线（轨道 §1 根因 / §4.1 契约）：引用外部应用的
    /// 脚本（tell application "X"）启动即轮询会触发 macOS 自动化授权弹窗。
    /// deferred 时 init 不执行不调度，item 显示占位「▶」；首次显式点按放行
    /// 后续自循环。无外部引用的脚本走原路径，行为零变化。
    private var deferredUntilTap = false

    init?(identifier: NSTouchBarItem.Identifier, source: SourceProtocol, interval: TimeInterval, alternativeImages: [String: SourceProtocol]) {
        self.interval = interval
        self.alternativeImages = alternativeImages
        self.sourceText = source.string ?? source.data?.utf8string
        super.init(identifier: identifier, title: "⏳")
        forceHideConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        // R60-a 守卫判定：deferred → 占位「▶」（title 语义非 alert）+ 接管
        // 单指点按为放行入口，init 到此为止（零执行零调度）；allowed → 原路径。
        if case .deferredUntilTap(let apps) = AppleScriptTCCGuard.startupPolicy(for: sourceText ?? "") {
            deferredUntilTap = true
            title = AppleScriptTCCGuard.deferredPlaceholderTitle
            #if DEBUG
                print("AppleScriptTouchBarItem: startup execution deferred until tap (references: \(apps.sorted().joined(separator: ", ")))")
            #endif
            actions = [ItemAction(trigger: .singleTap) { [weak self] in
                self?.releaseDeferredExecution()
            }]
            return
        }
        title = "scheduled"
        scheduleCompilation()
    }

    required init?(coder _: NSCoder) { return nil }

    /// R60-a：用户显式点按 → 放行一次。幂等（shouldRelease 在放行后恒 false，
    /// 重复点按为空操作）。不清空 actions：BarItemFactory 在 init 之后追加的
    /// 用户配置点按动作（legacy action / actions 数组）必须原样保留——放行后
    /// 点按行为与 R60 前一致（首拍同时表达「放行」与用户动作意图，后续拍
    /// 仅走用户动作），清空会让带 action 字段的遗留条目放行后失灵。
    private func releaseDeferredExecution() {
        guard AppleScriptTCCGuard.shouldRelease(deferred: deferredUntilTap) else { return }
        deferredUntilTap = false
        title = "scheduled"
        scheduleCompilation()
    }

    /// 「后台编译脚本 + 拉起自循环」共用段（原 init 逻辑原样；R60-a 仅改为
    /// 可被 deferred 放行二次调用）。
    private func scheduleCompilation() {
        DispatchQueue.appleScriptQueue.async { [weak self] in
            guard let self = self, let script = self.makeAppleScript() else {
                DispatchQueue.main.async {
                    self?.title = "no script"
                }
                return
            }
            self.script = script
            DispatchQueue.main.async {
                self.isBordered = false
            }

            var error: NSDictionary?
            guard script.compileAndReturnError(&error) else {
                #if DEBUG
                    print(error?.description ?? "unknown error")
                #endif
                DispatchQueue.main.async {
                    self.title = "error"
                }
                return
            }
            self.refreshAndSchedule()
        }
    }

    /// 取可编译脚本：已编译的复用；deferred 首次放行从保存的原文重建。
    private func makeAppleScript() -> NSAppleScript? {
        if let existing = script { return existing }
        guard let text = sourceText else { return nil }
        return NSAppleScript(source: text)
    }

    /// round 24：隐藏暂停——gate 变更检测（重复广播幂等）；恢复时补刷跳到
    /// 脚本队列执行（execute 为阻塞调用，不能放主线程）。
    func setPaused(_ paused: Bool) {
        guard pauseGate.setPaused(paused) else { return }
        if !paused, !deferredUntilTap {
            DispatchQueue.appleScriptQueue.async { [weak self] in
                self?.refreshAndSchedule()
            }
        }
    }

    func refreshAndSchedule() {
        // round 24：隐藏期间不执行脚本也不调度下一 hop，链在此终结；
        // 恢复时由 setPaused(false) 重新拉起（立即补刷一次 + 原节奏继续）。
        // R60-a：deferred 期间同样不执行（点按前链不存在）。
        guard !pauseGate.isPaused, !deferredUntilTap else { return }
        let scriptResult = execute()
        DispatchQueue.main.async {
            self.title = scriptResult
            self.forceHideConstraint.isActive = scriptResult == ""
        }
        DispatchQueue.appleScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.refreshAndSchedule()
        }
    }

    func updateIcon(iconLabel: String) {
        if alternativeImages[iconLabel] != nil {
            DispatchQueue.main.async {
                self.image = self.alternativeImages[iconLabel]!.image
            }
        } else {
            print("Cannot find icon with label \"\(iconLabel)\"")
        }
    }

    func execute() -> String {
        var error: NSDictionary?
        let output = script.executeAndReturnError(&error)
        if let error = error {
            print(error)
            return "error"
        }
        if output.descriptorType == typeAEList {
            let arr = Array(1...output.numberOfItems).compactMap({ output.atIndex($0)!.stringValue ?? "" })

            if arr.count <= 0 {
                return ""
            } else if arr.count == 1 {
                return arr[0]
            } else {
                updateIcon(iconLabel: arr[1])
                return arr[0]
            }
        }
        return output.stringValue ?? ""
    }
}

extension DispatchQueue {
    static let appleScriptQueue = DispatchQueue(label: "mtmr.applescript")
}
