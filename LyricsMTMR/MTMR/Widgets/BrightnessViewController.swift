import AppKit
import AVFoundation
import Cocoa
import CoreAudio

class BrightnessViewController: NSCustomTouchBarItem {
    private(set) var sliderItem: CustomSlider!
    private var timer: Timer?

    init(identifier: NSTouchBarItem.Identifier, refreshInterval: Double, image: NSImage? = nil) {
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

        let refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.updateBrightnessSlider()
        }
        RunLoop.current.add(refreshTimer, forMode: RunLoop.Mode.common)
        timer = refreshTimer
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        timer?.invalidate()
        sliderItem.unbind(NSBindingName.value)
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
