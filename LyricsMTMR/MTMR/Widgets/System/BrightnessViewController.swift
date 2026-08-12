import AppKit
import AVFoundation
import Cocoa
import CoreAudio

class BrightnessViewController: NSCustomTouchBarItem, TBPollPausable {
    private(set) var sliderItem: CustomSlider!

    /// 亮度轮询（round 20：隐藏期间整体暂停——每次刷新都调显示私有 API；
    /// .common 模式保持与改动前一致，拖动跟踪期间也照常刷新；恢复立即补刷）。
    private lazy var pausableTimer = TBPausableTimer(interval: refreshInterval, tolerance: refreshInterval * 0.1,
                                                     immediateFireOnResume: true, mode: .common) { [weak self] in
        self?.updateBrightnessSlider()
    }
    private let refreshInterval: TimeInterval

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, image: NSImage? = nil) {
        self.refreshInterval = refreshInterval
        super.init(identifier: identifier)

        if image == nil {
            sliderItem = CustomSlider()
        } else {
            sliderItem = CustomSlider(knob: image!)
        }
        sliderItem.target = self
        sliderItem.action = #selector(BrightnessViewController.sliderValueChanged(_:))
        sliderItem.minValue = 0.0
        sliderItem.maxValue = 100.0
        sliderItem.floatValue = getBrightness() * 100

        view = sliderItem

        pausableTimer.start()
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        sliderItem.unbind(NSBindingName.value)
    }

    /// 隐藏（黑名单/exitTouchbar）时暂停刷新轮询；显示时恢复并立即补刷。
    func setPaused(_ paused: Bool) {
        pausableTimer.setPaused(paused)
    }

    @objc func updateBrightnessSlider() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.sliderItem.floatValue = self.getBrightness() * 100
        }
    }

    @objc func sliderValueChanged(_ sender: Any) {
        if let sliderItem = sender as? NSSlider {
            setBrightness(level: Float32(sliderItem.intValue) / 100.0)
        }
    }

    private func getBrightness() -> Float32 {
        if #available(OSX 10.13, *) {
            return Float32(CoreDisplay_Display_GetUserBrightness(0))
        } else {
            var level: Float32 = 0.5
            let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))

            IODisplayGetFloatParameter(service, 0, kIODisplayBrightnessKey as CFString, &level)
            return level
        }
    }

    private func setBrightness(level: Float) {
        if #available(OSX 10.13, *) {
            CoreDisplay_Display_SetUserBrightness(0, Double(level))
        } else {
            let service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"))

            IODisplaySetFloatParameter(service, 1, kIODisplayBrightnessKey as CFString, level)
            IOObjectRelease(service)
        }
    }
}
