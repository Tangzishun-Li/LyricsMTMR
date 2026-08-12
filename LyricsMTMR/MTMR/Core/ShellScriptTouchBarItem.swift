//
//  ShellScriptTouchBarItem.swift
//  MTMR
//
//  Created by bobr on 08/08/2019.
//  Copyright © 2019 Anton Palgunov. All rights reserved.
//
import Foundation

class ShellScriptTouchBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let interval: TimeInterval
    private let source: String
    private var forceHideConstraint: NSLayoutConstraint!

    /// round 24 收官审计：隐藏暂停门。脚本 item 的 asyncAfter 自循环与 bar
    /// 显隐零关联——隐藏期（黑名单 app / exitTouchbar）仍按 interval spawn
    /// 进程执行用户脚本（任意 IO/网络/进程开销），属「持续轮询」类遗漏；
    /// 本卡纳入暂停：隐藏期链在下一 hop 终结（guard 拦截，不执行不调度），
    /// 恢复时立即补刷一次 + 按原节奏继续（同 MusicBarItem 自循环模式）。
    /// round 23 播种：隐藏期重建时 init 的首次执行被 guard 拦截。
    private let pauseGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)
    
    struct ScriptResult: Decodable {
        var title: String?
        var image: Source?
    }

    init?(identifier: NSTouchBarItem.Identifier, source: SourceProtocol, interval: TimeInterval) {
        self.interval = interval
        self.source = source.string ?? "echo No \"source\""
        super.init(identifier: identifier, title: "⏳")
        
        forceHideConstraint = view.widthAnchor.constraint(equalToConstant: 0)
        
        DispatchQueue.shellScriptQueue.async {
            self.refreshAndSchedule()
        }
    }
    
    required init?(coder _: NSCoder) { return nil }

    /// round 24：隐藏暂停——gate 变更检测（重复广播幂等）；恢复时补刷跳到
    /// 脚本队列执行（execute 为阻塞调用，不能放主线程）。
    func setPaused(_ paused: Bool) {
        guard pauseGate.setPaused(paused) else { return }
        if !paused {
            DispatchQueue.shellScriptQueue.async { [weak self] in
                self?.refreshAndSchedule()
            }
        }
    }
    
    func refreshAndSchedule() {
        // round 24：隐藏期间不执行脚本也不调度下一 hop，链在此终结；
        // 恢复时由 setPaused(false) 重新拉起（立即补刷一次 + 原节奏继续）。
        guard !pauseGate.isPaused else { return }
        // Execute script and get result
        let scriptResult = execute(source)
        var rawTitle: String, image: NSImage?
        var json: Bool

        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(ScriptResult.self, from: scriptResult.data(using: .utf8)!)
            json = true
            rawTitle = result.title ?? ""
            image = result.image?.image
        } catch {
            json = false
            rawTitle = scriptResult
        }

        // Apply returned text attributes (if they were returned) to our result string
        let helper = AMR_ANSIEscapeHelper.init()
        helper.defaultStringColor = NSColor.white
        helper.font = "1".defaultTouchbarAttributedString.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        let title = NSMutableAttributedString.init(attributedString: helper.attributedString(withANSIEscapedString: rawTitle) ?? NSAttributedString(string: ""))
        title.addAttributes([.baselineOffset: 1], range: NSRange(location: 0, length: title.length))
        let newBackgoundColor: NSColor? = title.length != 0 ? title.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor : nil
        
        // Update UI
        DispatchQueue.main.async { [weak self, newBackgoundColor] in
            if (newBackgoundColor != self?.backgroundColor) { // performance optimization because of reinstallButton
                self?.backgroundColor = newBackgoundColor
            }
            self?.attributedTitle = title
            if json {
                self?.image = image
            }
            self?.forceHideConstraint.isActive = scriptResult == ""
        }
        
        // Schedule next update
        DispatchQueue.shellScriptQueue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.refreshAndSchedule()
        }
    }
    
    func execute(_ command: String) -> String {
        let task = Process()
        if let shell = getenv("SHELL") {
            task.launchPath = String.init(cString: shell)
        } else {
            task.launchPath = "/bin/bash"
        }
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        // kill process if it is over update interval
        DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak task] in
            task?.terminate()
        }
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        var output: String = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as String? ?? ""
        
        //always wait until task end or you can catch "task still running" error while accessing task.terminationStatus variable
        task.waitUntilExit()
        if (output == "" && task.terminationStatus != 0) {
            output = "error"
        }
        
        return output.replacingOccurrences(of: "\\n+$", with: "", options: .regularExpression)
    }
}

extension DispatchQueue {
    static let shellScriptQueue = DispatchQueue(label: "mtmr.shellscript")
}
