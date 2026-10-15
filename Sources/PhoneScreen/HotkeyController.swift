import Carbon
import Foundation

/// Fixed emergency-disconnect hotkey ⌃⌥⌘⎋ (Carbon, no Accessibility needed).
final class HotkeyController {
    static let label = "⌃⌥⌘⎋"
    var onFire: () -> Void = {}
    private(set) var lastError: String?
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var installed = false

    func register() {
        installHandlerIfNeeded()
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5068_5363), id: 1) // 'PhSc'
        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKey = ref
            lastError = nil
        } else {
            lastError = "全局热键 \(Self.label) 注册失败（\(status)）。"
        }
    }

    private func installHandlerIfNeeded() {
        guard !installed else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let controller = Unmanaged<HotkeyController>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    controller.onFire()
                }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        installed = status == noErr
        if status != noErr {
            lastError = "无法安装热键事件（\(status)）。"
        }
    }
}
