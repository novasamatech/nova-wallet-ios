import Foundation

@propertyWrapper
struct Atomic<Value> {
    private let lock = NSLock()
    private var value: Value

    init(defaultValue: Value) {
        value = defaultValue
    }

    var wrappedValue: Value {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}
