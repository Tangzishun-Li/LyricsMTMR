import Foundation

class AppleScriptTouchBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private var script: NSAppleScript!
    private let interval: TimeInterval
    private var forceHideConstraint: NSLayoutConstraint!
    private let alternativeImages: [String: SourceProtocol]

    /// round 24 收官审计：隐藏暂停门。AppleScript 自循环与 bar 显隐零关联
    /// ——隐藏期仍按 interval 执行用户脚本（任意开销）；本卡纳入暂停：
    /// 隐藏期链在下一 hop 终结，恢复时立即补刷一次 + 按原节奏继续
    /// （同 ShellScriptTouchBarItem / MusicBarItem 模式）。
    /// round 23 播种：隐藏期重建时 init 的首次执行被 guard 拦截。
    private let pauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)

    init?(identifier: NSTouchBarItem.Identifier, source: SourceProtocol, interval: TimeInterval, alternativeImages: [String: SourceProtocol]) {
        self.interval = interval
        self.alternativeImages = alternativeImages
        super.init(identifier: identifier, title: "⏳")
        forceHideConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        title = "scheduled"
        DispatchQueue.appleScriptQueue.async {
            guard let script = source.appleScript else {
                DispatchQueue.main.async {
                    self.title = "no script"
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

    required init?(coder _: NSCoder) { return nil }

    /// round 24：隐藏暂停——gate 变更检测（重复广播幂等）；恢复时补刷跳到
    /// 脚本队列执行（execute 为阻塞调用，不能放主线程）。
    func setPaused(_ paused: Bool) {
        guard pauseGate.setPaused(paused) else { return }
        if !paused {
            DispatchQueue.appleScriptQueue.async { [weak self] in
                self?.refreshAndSchedule()
            }
        }
    }

    func refreshAndSchedule() {
        // round 24：隐藏期间不执行脚本也不调度下一 hop，链在此终结；
        // 恢复时由 setPaused(false) 重新拉起（立即补刷一次 + 原节奏继续）。
        guard !pauseGate.isPaused else { return }
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
