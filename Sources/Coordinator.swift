import SwiftUI
import AppKit
import Combine

/// Central brain: listens for idle, decides when to show a card, owns state.
final class Coordinator: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var stats = Stats()
    @Published var selectedDifficulty: DifficultyLevel {
        didSet {
            deck.setDifficulty(selectedDifficulty)
            UserDefaults.standard.set(selectedDifficulty.rawValue, forKey: Self.difficultyDefaultsKey)
        }
    }
    @Published private(set) var wrongBookEntries: [WrongBookEntry] = []

    /// How many seconds of no keyboard/mouse activity before a card pops up.
    /// 600 = 10 minutes. Set low (e.g. 10) while testing so you don't have to wait.
    let idleThreshold: TimeInterval = 600

    /// After you dismiss a card, wait this long before another can auto-appear.
    private let cooldown: TimeInterval = 45

    private let idleMonitor = IdleMonitor()
    private let popup = PopupController()
    private let deck: ClozeDeck
    private var wrongBookWindow: NSWindow?
    private var cooldownUntil = Date.distantPast
    private static let difficultyDefaultsKey = "selectedDifficulty"

    init() {
        let savedDifficulty = UserDefaults.standard.string(forKey: Self.difficultyDefaultsKey)
            .flatMap(DifficultyLevel.init(rawValue:)) ?? .beginner
        self.selectedDifficulty = savedDifficulty
        self.deck = ClozeDeck(difficulty: savedDifficulty)
        self.wrongBookEntries = deck.wrongBookEntries()

        idleMonitor.idleThreshold = idleThreshold
        idleMonitor.onIdle = { [weak self] in
            self?.handleIdle()
        }
        idleMonitor.start()
    }

    private func handleIdle() {
        guard isEnabled, !popup.isShowing, Date() > cooldownUntil else { return }
        showNextCard()
    }

    /// Called from the menu's "来一题" — bypasses cooldown.
    func triggerManually() {
        guard !popup.isShowing else { return }
        showNextCard()
    }

    func showWrongBook() {
        wrongBookEntries = deck.wrongBookEntries()

        if let wrongBookWindow {
            wrongBookWindow.contentViewController = NSHostingController(
                rootView: WrongBookView(entries: wrongBookEntries)
            )
            wrongBookWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = WrongBookView(entries: wrongBookEntries)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "错题本"
        window.contentViewController = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        wrongBookWindow = window
    }

    private func showNextCard() {
        guard let card = deck.nextCard() else { return }

        let view = ClozePopupView(
            card: card,
            onResult: { [weak self] correct in
                self?.deck.record(card: card, correct: correct)
                self?.wrongBookEntries = self?.deck.wrongBookEntries() ?? []
                self?.refreshWrongBookWindow()
                self?.stats.record(correct: correct)
            },
            onNext: { [weak self] in
                self?.popup.close()
                self?.showNextCard()
            },
            onClose: { [weak self] in
                self?.popup.close()
                self?.cooldownUntil = Date().addingTimeInterval(self?.cooldown ?? 45)
            },
            onSnooze: { [weak self] in
                self?.popup.close()
                self?.cooldownUntil = Date().addingTimeInterval(60 * 60) // 1 小时
            }
        )

        popup.show { view }
    }

    private func refreshWrongBookWindow() {
        guard let wrongBookWindow, wrongBookWindow.isVisible else { return }
        wrongBookWindow.contentViewController = NSHostingController(
            rootView: WrongBookView(entries: wrongBookEntries)
        )
    }
}
