import Foundation

protocol SchedulerProtocol: AnyObject {
    var isScheduled: Bool { get }

    func notifyAfter(_ seconds: TimeInterval)
    func cancel()
}

protocol SchedulerDelegate: AnyObject {
    func didTrigger(scheduler: SchedulerProtocol)
}

final class Scheduler: NSObject, SchedulerProtocol {
    weak var delegate: SchedulerDelegate?

    let callbackQueue: DispatchQueue?

    private var lock = NSLock()
    private var timer: DispatchSourceTimer?

    init(with delegate: SchedulerDelegate, callbackQueue: DispatchQueue? = nil) {
        self.delegate = delegate
        self.callbackQueue = callbackQueue

        super.init()
    }

    deinit {
        cancel()
    }

    var isScheduled: Bool {
        lock.lock()

        defer {
            lock.unlock()
        }

        return timer != nil
    }

    func notifyAfter(_ seconds: TimeInterval) {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()

        let milliseconds = Int(min(Double(Int.max), 1000.0 * seconds))

        timer = DispatchSource.makeTimerSource()
        timer?.schedule(
            deadline: .now() + .milliseconds(milliseconds),
            repeating: DispatchTimeInterval.never
        )
        timer?.setEventHandler { [weak self] in
            self?.handleTrigger()
        }

        timer?.resume()
    }

    func cancel() {
        lock.lock()

        defer {
            lock.unlock()
        }

        clearTimer()
    }

    private func clearTimer() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    @objc private func handleTrigger() {
        lock.lock()

        defer {
            lock.unlock()
        }

        timer = nil

        if let callbackQueue = callbackQueue {
            callbackQueue.async {
                self.delegate?.didTrigger(scheduler: self)
            }
        } else {
            delegate?.didTrigger(scheduler: self)
        }
    }
}
