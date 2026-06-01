import SwiftUI
import AppKit

@main
struct EnglishClozeApp: App {
    @StateObject private var coordinator = Coordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(coordinator)
        } label: {
            GapfillLogoMark(size: 18, colored: false)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// The dropdown shown when you click the menu-bar icon.
struct MenuContent: View {
    @EnvironmentObject private var coordinator: Coordinator

    private var todayWrongCount: Int {
        coordinator.wrongBookEntries.filter(\.isToday).count
    }

    private var historyWrongCount: Int {
        coordinator.wrongBookEntries.filter { !$0.isToday }.count
    }

    var body: some View {
        Button("来一题") {
            coordinator.triggerManually()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])

        Button(coordinator.isEnabled ? "暂停自动弹出" : "开启自动弹出") {
            coordinator.isEnabled.toggle()
        }

        Divider()

        Menu("难度：\(coordinator.selectedDifficulty.title)") {
            ForEach(DifficultyLevel.allCases) { difficulty in
                Button {
                    coordinator.selectedDifficulty = difficulty
                } label: {
                    HStack {
                        Text(difficulty.title)
                        if coordinator.selectedDifficulty == difficulty {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        }

        Button("错题本（今日 \(todayWrongCount) · 历史 \(historyWrongCount)）") {
            coordinator.showWrongBook()
        }

        Divider()

        Text("今日 \(coordinator.stats.todayCount) 题 · 正确率 \(coordinator.stats.accuracyText)")

        Divider()

        Button("退出") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
