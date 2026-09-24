import Foundation

final class Locked<Value> {
    private let mutex = NSLock()
    private var stored: Value

    init(_ initial: Value) {
        stored = initial
    }

    var value: Value {
        read { $0 }
    }

    func read<T>(_ body: (Value) -> T) -> T {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return body(stored)
    }

    func update(_ change: (inout Value) -> Void) {
        mutex.lock()
        change(&stored)
        mutex.unlock()
    }
}
