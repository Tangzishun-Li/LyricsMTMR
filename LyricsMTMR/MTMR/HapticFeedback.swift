//
//  HapticFeedback.swift
//  MTMR
//
//  Created by Anton Palgunov on 09/04/2018.
//  Copyright © 2018 Anton Palgunov. All rights reserved.
//
//  This source code is licensed under MIT.
//  See LICENSE file in the project root for full license information.
//

import IOKit

class HapticFeedback {

    // Here we have list of possible IDs for Haptic Generator Device. They are not constant
    // To find deviceID, you will need IORegistryExplorer app from Additional Tools for Xcode dmg
    // which you can download from https://developer.apple.com/download/more/?=Additional%20Tools
    // Open IORegistryExplorer app, search for "AppleMultitouchDevice" and get "Multitouch ID"
    // or "AppleMultitouchTrackpadHIDEventDriver" and get "mt-device-id"
    // There should be programmatic way to get it but I can't find, no docs for macOS :(
    private let possibleDeviceIDs: [UInt64] = [
        0x200_0000_0100_0000,   // MacBook Pro 2016/2017
        0x300_0000_8050_0000,   // MacBook Pro 2019/2018
        0x200_0000_0000_0024,   // MacBook Pro (13-inch, M1, 2020)
        0x200_0000_0000_0023,   // MacBook Pro M1 13-Inch 2020 with 1tb
        0x300_0000_0100_0000,   // Additional MacBook models
        0x200_0000_0000_0025,   // M1 Pro/M1 Max models
        0x200_0000_0000_0026,   // M2 models
        0x200_0000_0000_0027    // M2 Pro/M2 Max models
    ]

    // you can get a plist `otool -s __TEXT __tpad_act_plist /System/Library/PrivateFrameworks/MultitouchSupport.framework/Versions/Current/MultitouchSupport|tail -n +3|awk -F'\t' '{print $2}'|xxd -r -p`
    enum HapticType: Int32, CaseIterable {
        case back = 1
        case click = 2
        case weak = 3
        case medium = 4
        case weakMedium = 5
        case strong = 6
        case reserved1 = 15
        case reserved2 = 16
    }

    private var actuatorRef: CFTypeRef?
    /// When true, haptic feedback is unavailable and we skip all actuator calls entirely.
    /// This prevents private API calls from blocking gesture handling on M1/M2 Macs.
    private var isUnavailable = false

    static var instance = HapticFeedback()

    // MARK: - Init

    private init() {
        self.recreateDevice()
    }

    private func recreateDevice() {
        guard !isUnavailable else { return }

        if let actuatorRef = self.actuatorRef {
            MTActuatorClose(actuatorRef)
            self.actuatorRef = nil
        }

        // Try to find our Haptic device
        for deviceID in possibleDeviceIDs {
            let actuator = MTActuatorCreateFromDeviceID(deviceID).takeRetainedValue()
            if actuator != nil {
                self.actuatorRef = actuator
                print("[Haptic] ✅ Found actuator with device ID: 0x\(String(format: "%llX", deviceID))")
                return
            }
        }

        // No device found — disable haptic entirely for this session.
        // This is critical on M1/M2 Macs where the MultitouchSupport private
        // APIs may return non-nil but invalid handles that cause hangs.
        print("[Haptic] ❌ No matching device ID found. Haptic feedback disabled.")
        isUnavailable = true
        self.actuatorRef = nil
    }

    // MARK: - Tap action

    func tap(type: HapticType) {
        guard !isUnavailable else {
            print("[Haptic] ⏭️ Skip (unavailable)")
            return
        }
        guard AppSettings.hapticFeedbackState else {
            print("[Haptic] ⏭️ Skip (disabled in settings)")
            return
        }
        guard let actuator = self.actuatorRef else {
            print("[Haptic] ⏭️ Skip (no actuator ref)")
            return
        }

        print("[Haptic] 🔓 Opening actuator...")
        guard MTActuatorOpen(actuator) == kIOReturnSuccess else {
            print("[Haptic] ❌ MTActuatorOpen failed — disabling permanently")
            isUnavailable = true
            self.actuatorRef = nil
            return
        }

        print("[Haptic] ⚡ Actuating type=\(type.rawValue)...")
        _ = MTActuatorActuate(actuator, type.rawValue, 0, 0, 0)
        _ = MTActuatorClose(actuator)
        print("[Haptic] ✅ Tap complete")
    }

    // MARK: - Device ID Finder

    /// Scans a broad range of possible multitouch device IDs and reports which ones are valid.
    /// Runs at init and prints results to console.
    func scanAllDeviceIDs() {
        print("[Haptic] 🔍 Scanning all possible device IDs...")
        // Try all plausible device IDs in the multitouch range
        let testRange: [UInt64] = [
            0x200_0000_0100_0000,
            0x300_0000_8050_0000,
            0x300_0000_0100_0000,
            0x200_0000_0000_0020, 0x200_0000_0000_0021,
            0x200_0000_0000_0022, 0x200_0000_0000_0023,
            0x200_0000_0000_0024, 0x200_0000_0000_0025,
            0x200_0000_0000_0026, 0x200_0000_0000_0027,
            0x200_0000_0000_0028, 0x200_0000_0000_0029,
            0x200_0000_0000_002A, 0x200_0000_0000_002B,
            0x200_0000_0000_002C, 0x200_0000_0000_002D,
            0x200_0000_0000_002E, 0x200_0000_0000_002F,
            0x300_0000_0000_0000,
        ]

        var found: [UInt64] = []
        for deviceID in testRange {
            let actuator = MTActuatorCreateFromDeviceID(deviceID).takeRetainedValue()
            if actuator != nil {
                found.append(deviceID)
                MTActuatorClose(actuator)
            }
        }

        if found.isEmpty {
            print("[Haptic] ❌ No valid device IDs found in scanned range.")
            print("[Haptic] 💡 Try: system_profiler SPiBridgeDataType | grep -i 'Multitouch ID'")
        } else {
            print("[Haptic] ✅ Found \(found.count) valid device IDs:")
            for id in found {
                print("[Haptic]    0x\(String(format: "%llX", id))")
            }
        }
        print("[Haptic] 🔍 Scan complete")
    }
}