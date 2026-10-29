import Carbon
import Foundation

/// System-wide shortcut via Carbon's RegisterEventHotKey – needs no extra permissions.
final class HotKey {
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let id: UInt32
    private let action: () -> Void
    private let release: (() -> Void)?

    /// `release` fires when the shortcut is let go – for hold-to-talk.
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void, release: (() -> Void)? = nil) {
        self.action = action
        self.release = release
        id = Self.nextID
        Self.nextID += 1

        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            // Every HotKey installs a handler; only the one whose shortcut was pressed reacts.
            guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
            if GetEventKind(event) == UInt32(kEventHotKeyReleased) {
                DispatchQueue.main.async { hotKey.release?() }
            } else {
                DispatchQueue.main.async { hotKey.action() }
            }
            return noErr
        }, 2, &eventTypes, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_504E), id: id) // "CLPN"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
