import AppKit

/// Detects when the user has been idle (no keyboard/mouse) for a threshold,
/// and fires `onIdle` exactly once per idle stretch.
///
/// Note: secondsSinceLastEventType reads system-wide HID idle time and does
/// NOT require Accessibility permission, which keeps setup friction low.
final class IdleMonitor {
    var onIdle: (() -> Void)?
    var idleThreshold: TimeInterval = 60

    private var timer: Timer?
    private var firedForCurrentIdle = false

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Make sure it keeps firing while menus/tracking loops run.
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // kCGAnyInputEventType == ~0 : "time since ANY input event"
        let anyEvent = CGEventType(rawValue: ~0)!
        let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                           eventType: anyEvent)
        if idle >= idleThreshold {
            if !firedForCurrentIdle {
                firedForCurrentIdle = true
                onIdle?()
            }
        } else {
            // User became active again — re-arm for the next idle stretch.
            firedForCurrentIdle = false
        }
    }
}
