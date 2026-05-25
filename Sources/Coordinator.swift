import SwiftUI
import AppKit
import Combine

/// Central brain: listens for idle, decides when to show a card, owns state.
final class Coordinator: ObservableObject {
    @Published var isEnabled: Bool = true
    @Published var stats = Stats()

    /// How many seconds of no keyboard/mouse activity before a card pops up.
    /// 600 = 10 minutes. Set low (e.g. 10) while testing so you don't have to wait.
    let idleThreshold: TimeInterval = 600

    /// After you dismiss a card, wait this long before another can auto-appear.
    private let cooldown: TimeInterval = 45

    private let idleMonitor = IdleMonitor()
    private let popup = PopupController()
    private let deck = ClozeDeck()
    private var cooldownUntil = Date.distantPast

    init() {
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

    /// Called from the menu's "现在来一题" — bypasses cooldown.
    func triggerManually() {
        guard !popup.isShowing else { return }
        showNextCard()
    }

    private func showNextCard() {
        guard let card = deck.nextCard() else { return }

        let view = ClozePopupView(
            card: card,
            onResult: { [weak self] correct in
                self?.deck.record(card: card, correct: correct)
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
}
