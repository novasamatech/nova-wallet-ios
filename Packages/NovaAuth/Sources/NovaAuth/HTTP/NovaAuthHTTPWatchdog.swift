import Foundation
import Operation_iOS

final class NovaAuthHTTPWatchdog<T> {
    weak var operation: BaseOperation<T>?
    private let timeout: TimeInterval
    private let mutex = NSLock()
    private var settled = false
    private var timer: DispatchWorkItem?

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func arm() {
        let timer = DispatchWorkItem { [weak self] in self?.expire() }
        mutex.novaAuthLocked { self.timer = timer }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout, execute: timer)
    }

    func settle() -> Bool {
        mutex.novaAuthLocked {
            guard !settled else { return false }
            settled = true
            timer?.cancel()
            timer = nil
            return true
        }
    }
}

private extension NovaAuthHTTPWatchdog {
    func expire() {
        guard let operation, !operation.isFinished, settle() else { return }
        operation.result = .failure(NovaAuthError.transport(.timedOut))
        operation.cancel()
    }
}
