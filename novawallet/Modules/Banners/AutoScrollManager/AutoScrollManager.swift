import Foundation

final class AutoScrollManager {
    private weak var scrollable: AutoScrollable?
    private var timer: Timer?
    private let timeInterval: TimeInterval

    init(
        scrollable: AutoScrollable,
        timeInterval: TimeInterval = 4.0
    ) {
        self.scrollable = scrollable
        self.timeInterval = timeInterval
    }

    deinit {
        stopTimer()
    }
}

private extension AutoScrollManager {
    func startTimer() {
        timer = Timer.scheduledTimer(
            withTimeInterval: timeInterval,
            repeats: true
        ) { [weak self] _ in
            self?.scrollable?.scrollToNextItem()
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AutoScrollManager {
    func setupScrolling() {
        if timer != nil {
            stopTimer()
        }

        startTimer()
    }

    func stopScrolling() {
        stopTimer()
    }
}
