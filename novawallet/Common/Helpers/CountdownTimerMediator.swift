import Foundation
import Foundation_iOS

protocol CountdownTimerMediating {
    var remainedInterval: TimeInterval { get }

    func addObserver(_ delegate: CountdownTimerDelegate)
    func removeObserver(_ delegate: CountdownTimerDelegate)

    func start(with totalTime: TimeInterval)
    func stop()
}

/**
 * Allows to add multiple delegates to one timer. Implementation not thread safe and intended to be used only
 * from main thread.
 */

final class CountdownTimerMediator {
    private var observers: [WeakWrapper] = []

    private let timer = CountdownTimer()

    private func clear() {
        observers = observers.filter { $0.target != nil }
    }

    private func forEachObserver(_ closure: (CountdownTimerDelegate) -> Void) {
        observers.forEach { observer in
            if let target = observer.target as? CountdownTimerDelegate {
                closure(target)
            }
        }
    }
}

extension CountdownTimerMediator: CountdownTimerMediating {
    var remainedInterval: TimeInterval { timer.remainedInterval }

    func addObserver(_ delegate: CountdownTimerDelegate) {
        clear()

        guard !observers.contains(where: { $0.target === delegate }) else {
            return
        }

        observers.append(WeakWrapper(target: delegate))
    }

    func removeObserver(_ delegate: CountdownTimerDelegate) {
        clear()

        observers = observers.filter { $0.target !== delegate }
    }

    func start(with totalTime: TimeInterval) {
        timer.delegate = self

        timer.start(with: totalTime)
    }

    func stop() {
        timer.delegate = nil
        timer.stop()
    }
}

extension CountdownTimerMediator: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        forEachObserver { $0.didStart(with: interval) }
    }

    func didCountdown(remainedInterval: TimeInterval) {
        forEachObserver { $0.didCountdown(remainedInterval: remainedInterval) }
    }

    func didStop(with remainedInterval: TimeInterval) {
        forEachObserver { $0.didStop(with: remainedInterval) }
    }
}
