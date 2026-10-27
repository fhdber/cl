import AppKit

/// Opens the shelf when the pointer rests at the top centre of a screen (the notch).
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

    private static func pointerInNotchZone() -> Bool {
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) else { return false }
        return point.y >= screen.frame.maxY - 3 && abs(point.x - screen.frame.midX) <= 120
    }

    private func check() {
        guard Self.pointerInNotchZone() else {
            pending?.cancel()
            pending = nil
            return
        }
        guard pending == nil else { return }
        // A short dwell, so merely passing the menu bar doesn't pop the shelf.
        let work = DispatchWorkItem { [weak self] in
            self?.pending = nil
            if Self.pointerInNotchZone() { self?.onTrigger() }
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}
