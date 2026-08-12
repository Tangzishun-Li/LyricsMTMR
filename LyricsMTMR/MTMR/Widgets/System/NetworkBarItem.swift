//
//  NetworkBarItem.swift
//  MTMR
//
//  Created by Anton Palgunov on 23/02/2019.
//  Copyright © 2019 Anton Palgunov. All rights reserved.
//

import Foundation

class NetworkBarItem: CustomButtonTouchBarItem, Widget, TBPollPausable {
    static var name: String = "network"
    static var identifier: String = "com.toxblh.mtmr.network"
    
    private let flip: Bool
    private let units: String
    private var bandwidthProcess: Process?
    private var dataObserver: NSObjectProtocol?

    /// round 24 收官审计：隐藏暂停门。netstat 常驻进程（-w1 每秒输出）与 bar
    /// 显隐零关联——隐藏期进程持续运行、每秒回调解析 + 主线程 attributedTitle
    /// 重建（事件驱动源在隐藏期持续产生事件，同 round 21 采集链论证）；本卡
    /// 纳入暂停：隐藏期终止进程 + 移除 observer（零进程零回调），恢复时重启
    /// 监控（首个数据块即补刷）。round 23 播种：隐藏期重建时 init 不启动。
    private let pollGate = TBPauseGate(startPaused: TouchBarVisibilityState.shared.isBarHidden)
    
    init(identifier: NSTouchBarItem.Identifier, flip: Bool = false, units: String) {
        self.flip = flip
        self.units = units
        super.init(identifier: identifier, title: " ")
        if !pollGate.isPaused {
            startMonitoringProcess()
        }
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        stopMonitoringProcess()
    }

    /// round 24：隐藏暂停——gate 变更检测（重复广播幂等）；暂停终止进程，
    /// 恢复重启（重启无副作用：netstat 为系统命令，无授权状态机）。
    func setPaused(_ paused: Bool) {
        guard pollGate.setPaused(paused) else { return }
        if paused {
            stopMonitoringProcess()
        } else {
            startMonitoringProcess()
        }
    }

    /// 停止监控进程（幂等；deinit 与隐藏暂停共用）。internal：单测注入点。
    func stopMonitoringProcess() {
        if let observer = dataObserver {
            NotificationCenter.default.removeObserver(observer)
            dataObserver = nil
        }
        bandwidthProcess?.terminate()
        bandwidthProcess = nil
    }

    func startMonitoringProcess() {
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = ["netstat", "-w1", "-l", "en0"]
        process.standardOutput = pipe
        bandwidthProcess = process

        let outputHandle = pipe.fileHandleForReading
        outputHandle.waitForDataInBackgroundAndNotify(forModes: [RunLoop.Mode.common])

        dataObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSFileHandleDataAvailable,
            object: outputHandle,
            queue: nil
        ) { [weak self] _ -> Void in
            guard let self = self else { return }
            let data = outputHandle.availableData
            if data.count > 0 {
                if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                    let curr = str
                        .replacingOccurrences(of: "  ", with: " ")
                        .split(separator: " ")
                    if curr.count >= 6, let dVal = UInt64(curr[2]), let uVal = UInt64(curr[5]) {
                        DispatchQueue.main.async { [weak self] in
                            self?.setTitle(up: self?.getHumanizeSize(speed: uVal) ?? "", down: self?.getHumanizeSize(speed: dVal) ?? "")
                        }
                    }
                }
                outputHandle.waitForDataInBackgroundAndNotify()
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                if let observer = self?.dataObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.dataObserver = nil
                }
            }
        }

        process.launch()
    }

    func getHumanizeSize(speed: UInt64) -> String {
        let humanText: String
        
        func speedB(speed: UInt64)-> String {
            return String(format: "%.0f", Double(speed)) + " B/s"
        }
        
        func speedKB(speed: UInt64)-> String {
            return String(format: "%.1f", Double(speed) / 1024) + " KB/s"
        }
        
        func speedMB(speed: UInt64)-> String {
            return String(format: "%.1f", Double(speed) / (1024 * 1024)) + " MB/s"
        }
        
        func speedGB(speed: UInt64)-> String {
            return String(format: "%.2f", Double(speed) / (1024 * 1024 * 1024)) + " GB/s"
        }
        
        switch self.units {
        case "B/s":
            humanText = speedB(speed: speed)
        case "KB/s":
            humanText = speedKB(speed: speed)
        case "MB/s":
            humanText = speedMB(speed: speed)
        case "GB/s":
            humanText = speedGB(speed: speed)
        default:
            if speed < 1024 {
                humanText = speedB(speed: speed)
            } else if speed < (1024 * 1024) {
                humanText = speedKB(speed: speed)
            } else if speed < (1024 * 1024 * 1024) {
                humanText = speedMB(speed: speed)
            } else {
                humanText = speedGB(speed: speed)
            }
        }

        return humanText
    }
    
    func appendUpSpeed(appendString: NSMutableAttributedString, up: String, titleFont: NSFont, newStr: Bool = false) {
        appendString.append(NSMutableAttributedString(
            string: newStr ? "\n↑" : "↑",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.blue,
                NSAttributedString.Key.font: titleFont,
                ]))
        
        appendString.append(NSMutableAttributedString(
            string: up,
            attributes: [
                NSAttributedString.Key.font: titleFont,
                ]))
    }
    
    func appendDownSpeed(appendString: NSMutableAttributedString, down: String, titleFont: NSFont, newStr: Bool = false) {
        appendString.append(NSMutableAttributedString(
            string: newStr ? "\n↓" : "↓",
            attributes: [
                NSAttributedString.Key.foregroundColor: NSColor.red,
                NSAttributedString.Key.font: titleFont,
                ]))
            
            appendString.append(NSMutableAttributedString(
                string: down,
                attributes: [
                    NSAttributedString.Key.font: titleFont
                ]))
    }
    
    func setTitle(up: String, down: String) {
        let titleFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: NSFont.Weight.light)
        
        let newTitle: NSMutableAttributedString = NSMutableAttributedString(string: "")
        
        if (self.flip) {
            appendUpSpeed(appendString: newTitle, up: up, titleFont: titleFont)
            appendDownSpeed(appendString: newTitle, down: down, titleFont: titleFont, newStr: true)
        } else {
            appendDownSpeed(appendString: newTitle, down: down, titleFont: titleFont)
            appendUpSpeed(appendString: newTitle, up: up, titleFont: titleFont, newStr: true)
        }
        
        
        self.attributedTitle = newTitle
    }
}
