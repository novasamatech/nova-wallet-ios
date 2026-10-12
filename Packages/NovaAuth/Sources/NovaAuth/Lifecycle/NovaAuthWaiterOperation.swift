import Foundation
import Operation_iOS

final class NovaAuthCancellation {
    private let lock = NSLock()
    private var action: (() -> Void)?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func install(_ action: @escaping () -> Void) {
        lock.lock()
        let shouldCancel = cancelled
        if !shouldCancel { self.action = action }
        lock.unlock()
        if shouldCancel { action() }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let callback = action
        action = nil
        lock.unlock()
        callback?()
    }

    func check() throws {
        if isCancelled { throw NovaAuthError.cancelled }
    }
}

final class NovaAuthWaiterOperation<Value>: BaseOperation<Value>, @unchecked Sendable {
    let cancellation = NovaAuthCancellation()
    private let startWork: (NovaAuthCancellation, @escaping (Result<Value, Error>) -> Void) -> Void

    init(start: @escaping (NovaAuthCancellation, @escaping (Result<Value, Error>) -> Void) -> Void) {
        startWork = start
        super.init()
    }

    override func performAsync(_ callback: @escaping (Result<Value, Error>) -> Void) throws {
        try cancellation.check()
        startWork(cancellation, callback)
    }

    override func cancel() {
        cancellation.cancel()
        super.cancel()
    }
}

extension NSLock {
    func novaAuthLocked<Value>(_ body: () throws -> Value) rethrows -> Value {
        lock()
        defer { unlock() }
        return try body()
    }
}
