//
//  CPUBarItem.swift
//  MTMR
//
//  Created by bobrosoft on 17/08/2021.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Foundation

class CPUBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let refreshInterval: TimeInterval
    private var refreshQueue: DispatchQueue? = DispatchQueue(label: "mtmr.cpu")
    /// 隐藏期间暂停自循环（round 19）：暂停后已触发的 hop 直接返回且不再调度下一 hop。
    private let pauseGate = TBPauseGate()
    private let defaultSingleTapScript: NSAppleScript! = "activate application \"Activity Monitor\"\rtell application \"System Events\"\r\ttell process \"Activity Monitor\"\r\t\ttell radio button \"CPU\" of radio group 1 of group 2 of toolbar 1 of window 1 to perform action \"AXPress\"\r\tend tell\rend tell".appleScript

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: TimeInterval) {
        self.refreshInterval = refreshInterval
        super.init(identifier: identifier, title: "⏳")
                
        // Set default image
        if self.image == nil {
            self.image = #imageLiteral(resourceName: "cpu").resize(maxSize: NSSize(width: 24, height: 24));
        }
        
        // Set default action
        if actions.filter({ $0.trigger == .singleTap }).isEmpty {
            actions.append(ItemAction(
                trigger: .singleTap,
                defaultTapAction
            ))
        }
        
        refreshAndSchedule()
    }

    required init?(coder _: NSCoder) { return nil }
    
    func refreshAndSchedule() {
        // 隐藏（黑名单/exitTouchbar）期间：既不采样也不调度下一 hop，链在此终结；
        // 恢复时由 setPaused(false) 重新拉起（立即采样一次 + 按原节奏继续）。
        guard !pauseGate.isPaused else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Get CPU load
            let usage = 100 - CPU.systemUsage().idle
            guard usage.isFinite else {
                return
            }
            
            // Choose color based on CPU load
            var color: NSColor? = nil
            var bgColor: NSColor? = nil
            if usage > 70 {
                color = .black
                bgColor = .yellow
            } else if usage > 30 {
                color = .yellow
            }
            
            // Update layout
            let attrTitle = NSMutableAttributedString.init(attributedString: String(format: "%.1f%%", usage).defaultTouchbarAttributedString)
            if let color = color {
                attrTitle.addAttributes([.foregroundColor: color], range: NSRange(location: 0, length: attrTitle.length))
            }
            self.attributedTitle = attrTitle
            self.backgroundColor = bgColor
        }
        
        refreshQueue?.asyncAfter(deadline: .now() + refreshInterval) { [weak self] in
            self?.refreshAndSchedule()
        }
    }

    func defaultTapAction() {
        refreshQueue?.async { [weak self] in
            self?.defaultSingleTapScript.executeAndReturnError(nil)
        }
    }

    /// 隐藏时暂停自循环（链在下一 hop 处终结）；显示时恢复（立即采样一次再按原间隔继续）。
    func setPaused(_ paused: Bool) {
        if pauseGate.setPaused(paused), !paused {
            refreshAndSchedule()
        }
    }

    deinit {
        // 不能在这里 suspend 队列：libdispatch 会以「Refusing to dispose of a
        // dispatch queue with pending suspension count」EXC_BREAKPOINT 崩溃
        // （潜伏缺陷，round 19 单测暴露）。链上所有 block 均 [weak self]，
        // 释放队列即安全，无需挂起。
        refreshQueue = nil
    }
}
