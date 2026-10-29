import AppKit

/// Opens the shelf when the pointer moves into the menu bar, centred under the notch.
final class NotchHover {
    private var monitors: [Any] = []
    private var pending: DispatchWorkItem?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        guard monitors.isEmpty else { return }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] _ in
            self?.check()
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { [weak self] event in
            self?.check()
            return event
        }) {
            monitors.append(local)
        }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        pending?.cancel()
        pending = nil
    }

    /// Only the middle of the menu bar: the notch itself, or 160 pt where there is none –
    /// so reaching for a menu or a status icon never pops the shelf.
    static func triggerZone(on screen: NSScreen) -> NSRect {
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        var width: CGFloat = 160
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            width = max(120, screen.frame.width - left.width - right.width)
        }
        return NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - menuBarHeight,
                      width: width, height: menuBarHeight)
    }

    static func pointerInZone() -> Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return false }
        return NSMouseInRect(point, triggerZone(on: screen), false)
    }

    private func check() {
        guard Self.pointerInZone() else {
            pending?.cancel()
            pending = nil
            return
        }
        guard pending == nil else { return }
        // A short dwell, so merely crossing the menu bar doesn't pop the shelf.
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            if Self.pointerInZone() { self?.onTrigger() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}
