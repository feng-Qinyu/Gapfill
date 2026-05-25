import SwiftUI
import AppKit

@main
struct EnglishClozeApp: App {
    @StateObject private var coordinator = Coordinator()

    var body: some Scene {
        MenuBarExtra("Gapfill", systemImage: "text.book.closed.fill") {
            MenuContent()
                .environmentObject(coordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The dropdown shown when you click the menu-bar icon.
struct MenuContent: View {
    @EnvironmentObject private var coordinator: Coordinator

    var body: some View {
        Button(coordinator.isEnabled ? "暂停自动弹出" : "开启自动弹出") {
            coordinator.isEnabled.toggle()
        }

        Button("现在来一题") {
            coordinator.triggerManually()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])

        Divider()

        Text("空闲 \(Int(coordinator.idleThreshold)) 秒后弹出")
        Text("今日 \(coordinator.stats.todayCount) 题 · 正确率 \(coordinator.stats.accuracyText)")

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
