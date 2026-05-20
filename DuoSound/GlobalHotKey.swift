import Carbon
import AppKit

// Registers ⌥⌘D as a global hotkey using Carbon RegisterEventHotKey.
// No Accessibility permission required — Carbon hot keys work system-wide
// without prompting the user.
final class GlobalHotKey {

    var action: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let ptr = userData else { return noErr }
                let hk = Unmanaged<GlobalHotKey>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { hk.action?() }
                return noErr
            },
            1, &eventType, selfPtr, &eventHandlerRef
        )

        var hotKeyID = EventHotKeyID(signature: fourCC("DUO1"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
    }

    func unregister() {
        hotKeyRef.map { UnregisterEventHotKey($0) }
        eventHandlerRef.map { RemoveEventHandler($0) }
        hotKeyRef = nil
        eventHandlerRef = nil
    }

    private func fourCC(_ s: String) -> FourCharCode {
        s.unicodeScalars.prefix(4).reduce(FourCharCode(0)) { ($0 << 8) | FourCharCode($1.value) }
    }
}
