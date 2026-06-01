import SwiftUI
import AppKit

/// NSPanel 子类：允许成为 key window，同时保持 nonactivating（不抢夺其他 app 焦点）。
/// 没有这个覆写，nonactivatingPanel 默认 canBecomeKey = false，文本框收不到键盘输入。
private class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Shows a small, non-activating floating card in the top-right corner.
final class PopupController {
    private var panel: KeyablePanel?

    var isShowing: Bool { panel != nil }

    func show<Content: View>(@ViewBuilder content: () -> Content) {
        close()

        let hosting = NSHostingController(rootView: content())
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.view.layer?.cornerRadius = 24
        hosting.view.layer?.cornerCurve = .continuous
        hosting.view.layer?.masksToBounds = true

        let panel = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 340),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hosting
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView?.layer?.cornerRadius = 24
        panel.contentView?.layer?.cornerCurve = .continuous
        panel.contentView?.layer?.masksToBounds = true

        // Size to fit the SwiftUI content, then pin to the top-right.
        panel.layoutIfNeeded()
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let size = panel.frame.size
            let x = visible.maxX - size.width - 20
            let y = visible.maxY - size.height - 20
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFrontRegardless()
        // 让面板成为 key window，SwiftUI @FocusState 才能把焦点传给文本框
        panel.makeKey()
        self.panel = panel
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}
