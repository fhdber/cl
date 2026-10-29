import AppKit

/// Notices a file being dragged up to the notch and opens the shelf on the tray,
/// like NotchNook. Polls cheaply while the mouse button is down, because global event
/// monitors don't see the drag once a drag session has started.
final class DragWatcher {
    private var timer: Timer?
    private var baseline = NSPasteboard(name: .drag).changeCount
    private var buttonWasDown = false
    private var triggered = false
    private let onFileDragAtNotch: () -> Void

    init(onFileDragAtNotch: @escaping () -> Void) {
        self.onFileDragAtNotch = onFileDragAtNotch
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let down = NSEvent.pressedMouseButtons & 1 != 0
        let pasteboard = NSPasteboard(name: .drag)
        if down && !buttonWasDown {
            baseline = pasteboard.changeCount
            triggered = false
        }
        buttonWasDown = down
        guard down, !triggered, pasteboard.changeCount != baseline,
              pasteboard.types?.contains(.fileURL) == true,
              Self.pointerNearNotch() else { return }
        triggered = true
        onFileDragAtNotch()
    }

    private static func pointerNearNotch() -> Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return false }
        // A little more forgiving than the hover zone: anywhere in the menu bar strip plus 40 pt below.
        let zone = NotchHover.triggerZone(on: screen)
        return NSMouseInRect(point, zone.insetBy(dx: -40, dy: 0).offsetBy(dx: 0, dy: -20).union(zone), false)
    }
}
