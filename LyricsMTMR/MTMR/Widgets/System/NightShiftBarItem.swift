//
//  NightShiftBarItem.swift
//  MTMR
//
//  Created by Anton Palgunov on 28/08/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Foundation

class NightShiftBarItem: CustomButtonTouchBarItem, TBPollPausable {
    private let nsclient = CBBlueLightClient()

    /// 1s 状态轮询（round 20：隐藏期间整体暂停——每次 refresh 都走
    /// CoreBrightness 私有 API 查询，隐藏期空转成本高；恢复后立即补刷）。
    private lazy var pausableTimer = TBPausableTimer(interval: 1, tolerance: 0.1, immediateFireOnResume: true) { [weak self] in
        self?.refresh()
    }

    private var blueLightStatus: Status {
        var status: Status = Status()
        nsclient.getBlueLightStatus(&status)
        return status
    }

    private var isNightShiftEnabled: Bool {
        return blueLightStatus.enabled.boolValue
    }

    private func setNightShift(state: Bool) {
        nsclient.setEnabled(state)
    }

    init(identifier: NSTouchBarItem.Identifier) {
        super.init(identifier: identifier, title: "")
        isBordered = false
        setWidth(value: 28)
        
        actions.append(ItemAction(trigger: .singleTap) { [weak self] in self?.nightShiftAction() })

        pausableTimer.start()

        refresh()
    }

    required init?(coder _: NSCoder) { return nil }

    /// 隐藏（黑名单/exitTouchbar）时暂停 1s 轮询；显示时恢复并立即刷新。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    func nightShiftAction() {
        setNightShift(state: !isNightShiftEnabled)
        refresh()
    }

    @objc func refresh() {
        image = isNightShiftEnabled ? #imageLiteral(resourceName: "nightShiftOn") : #imageLiteral(resourceName: "nightShiftOff")
    }
}
