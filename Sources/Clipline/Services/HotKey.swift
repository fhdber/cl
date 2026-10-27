import Carbon
import Foundation

/// System-wide shortcut via Carbon's RegisterEventHotKey – needs no extra permissions.
final class HotKey {
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let id: UInt32
    private let action: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        id = Self.nextID
        Self.nextID += 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            // Every HotKey installs a handler; only the one whose shortcut was pressed reacts.
            guard pressed.id == hotKey.id else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { hotKey.action() }
            return noErr
        }, 1, &eventType, context, &handlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x434C_504E), id: id) // "CLPN"
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
