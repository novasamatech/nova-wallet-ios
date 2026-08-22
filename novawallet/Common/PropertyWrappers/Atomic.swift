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

    // Use this for every read-modify-write, never `wrappedValue` twice and never `inout`
    // (`someHelper(&atomicProperty)`). An `inout` access opens a single exclusive access spanning
    // the whole get/modify/set, and at -O the optimizer hoists the read out of the lock and makes
    // the write-back release the value seen when the access opened rather than the one in the slot
    // when it closes. Two threads then release the same stored reference twice.
    mutating func exchange(_ newValue: Value) -> Value {
        lock.lock()
        defer { lock.unlock() }

        let oldValue = value
        value = newValue

        return oldValue
    }
}
