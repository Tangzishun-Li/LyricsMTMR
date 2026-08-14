import AppKit
import AVFoundation
import Cocoa
import CoreAudio

class VolumeViewController: NSCustomTouchBarItem {
    private(set) var sliderItem: CustomSlider!
    private var currentDeviceId: AudioObjectID = AudioObjectID(0)

    /// round 40：CoreAudio property-listener 注册用 block 句柄。原实现直接把
    /// 实例方法引用（audioRouteChanged / audioObjectPropertyListenerBlock）传给
    /// AudioObjectAddPropertyListenerBlock——方法引用默认强捕获 self，而 deinit
    /// 从不移除监听 → CoreAudio（系统对象）进程生命周期持有每个构造实例 = 真实泄漏
    /// （bar 每次重建累积）。现改为弱捕获闭包 + deinit 成对移除；block 存属性保证
    /// add/remove 指向同一 block（AudioObjectRemovePropertyListenerBlock 要求恒等）。
    private var routeChangeBlock: AudioObjectPropertyListenerBlock?
    private var volumeChangeBlock: AudioObjectPropertyListenerBlock?

    init(identifier: NSTouchBarItem.Identifier, image: NSImage? = nil) {
        super.init(identifier: identifier)

        if image == nil {
            sliderItem = CustomSlider()
        } else {
            sliderItem = CustomSlider(knob: image!)
        }
        sliderItem.target = self
        sliderItem.action = #selector(VolumeViewController.sliderValueChanged(_:))
        sliderItem.minValue = 0.0
        sliderItem.maxValue = 100.0
        sliderItem.floatValue = getInputGain() * 100

        view = sliderItem
        
        currentDeviceId = defaultDeviceID
        self.addAudioRouteChangedListener()
        self.addCurrentAudioVolumeChangedListener()
    }
    
    private func addAudioRouteChangedListener() {
        let audioId = AudioObjectID(bitPattern: kAudioObjectSystemObject)
        var forPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] numberAddresses, addresses in
            self?.audioRouteChanged(numberAddresses: numberAddresses, addresses: addresses)
        }
        routeChangeBlock = block
        AudioObjectAddPropertyListenerBlock(audioId, &forPropertyAddress, nil, block)
    }

    private func removeAudioRouteChangedListener() {
        guard let block = routeChangeBlock else { return }
        let audioId = AudioObjectID(bitPattern: kAudioObjectSystemObject)
        var forPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectRemovePropertyListenerBlock(audioId, &forPropertyAddress, nil, block)
        routeChangeBlock = nil
    }

    func audioRouteChanged(numberAddresses _: UInt32, addresses _: UnsafePointer<AudioObjectPropertyAddress>) {
        self.removeLastAudioVolumeChangeListener()
        currentDeviceId = defaultDeviceID
        self.addCurrentAudioVolumeChangedListener()
        DispatchQueue.main.async {
            self.sliderItem.floatValue = self.getInputGain() * 100
        }
    }
    
    private func addCurrentAudioVolumeChangedListener() {
        var forPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] numberAddresses, addresses in
            self?.audioObjectPropertyListenerBlock(numberAddresses: numberAddresses, addresses: addresses)
        }
        volumeChangeBlock = block
        AudioObjectAddPropertyListenerBlock(defaultDeviceID, &forPropertyAddress, nil, block)
    }
    
    private func removeLastAudioVolumeChangeListener() {
        guard let block = volumeChangeBlock else { return }
        var forPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        AudioObjectRemovePropertyListenerBlock(currentDeviceId, &forPropertyAddress, nil, block)
        volumeChangeBlock = nil
    }

    func audioObjectPropertyListenerBlock(numberAddresses _: UInt32, addresses _: UnsafePointer<AudioObjectPropertyAddress>) {
        DispatchQueue.main.async {
            self.sliderItem.floatValue = self.getInputGain() * 100
        }
    }

    required init?(coder _: NSCoder) { return nil }

    deinit {
        removeAudioRouteChangedListener()
        removeLastAudioVolumeChangeListener()
        sliderItem.unbind(NSBindingName.value)
    }

    @objc func sliderValueChanged(_ sender: Any) {
        if let sliderItem = sender as? NSSlider {
            _ = setInputGain(Float32(sliderItem.intValue) / 100.0)
        }
    }

    private var defaultDeviceID: AudioObjectID {
        var deviceID: AudioObjectID = AudioObjectID(0)
        var size: UInt32 = UInt32(MemoryLayout<AudioObjectID>.size)
        var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice)
        address.mScope = AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal)
        address.mElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return deviceID
    }

    private func getInputGain() -> Float32 {
        var volume: Float32 = 0.5
        var size: UInt32 = UInt32(MemoryLayout.size(ofValue: volume))
        var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = AudioObjectPropertySelector(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        address.mScope = AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput)
        address.mElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(defaultDeviceID, &address, 0, nil, &size, &volume)
        return volume
    }

    private func setInputGain(_ volume: Float32) -> OSStatus {
        var inputVolume: Float32 = volume

        if inputVolume == 0.0 {
            _ = setMute(mute: 1)
        } else {
            _ = setMute(mute: 0)
        }

        let size: UInt32 = UInt32(MemoryLayout.size(ofValue: inputVolume))
        var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mScope = AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput)
        address.mElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        address.mSelector = AudioObjectPropertySelector(kAudioHardwareServiceDeviceProperty_VirtualMainVolume)
        return AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &inputVolume)
    }

    private func setMute(mute: Int) -> OSStatus {
        var muteVal: Int = mute
        var address: AudioObjectPropertyAddress = AudioObjectPropertyAddress()
        address.mSelector = AudioObjectPropertySelector(kAudioDevicePropertyMute)
        let size: UInt32 = UInt32(MemoryLayout.size(ofValue: muteVal))
        address.mScope = AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput)
        address.mElement = AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        return AudioObjectSetPropertyData(defaultDeviceID, &address, 0, nil, size, &muteVal)
    }
}
