//
//  NightShiftBarItem.swift
//  MTMR
//
//  Created by Anton Palgunov on 28/08/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//

import Foundation

class NightShiftBarItem: CustomButtonTouchBarItem {
    private let nsclient = CBBlueLightClient()
    private var timer: Timer?

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

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        timer?.tolerance = 0.1

        refresh()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        timer?.invalidate()
    }

    func nightShiftAction() {
        setNightShift(state: !isNightShiftEnabled)
        refresh()
    }

    @objc func refresh() {
        image = isNightShiftEnabled ? #imageLiteral(resourceName: "nightShiftOn") : #imageLiteral(resourceName: "nightShiftOff")
    }
}
