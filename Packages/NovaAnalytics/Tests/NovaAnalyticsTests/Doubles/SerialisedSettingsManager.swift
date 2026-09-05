import Foundation
import Keystore_iOS

final class SerialisedSettingsManager: SettingsManagerProtocol {
    private let wrapped: SettingsManagerProtocol
    private let lock = NSLock()

    init(wrapping wrapped: SettingsManagerProtocol = InMemorySettingsManager()) {
        self.wrapped = wrapped
    }

    private func synchronised<T>(_ body: () -> T) -> T {
        lock.lock()

        defer {
            lock.unlock()
        }

        return body()
    }

    func set(value: Bool, for key: String) {
        synchronised { wrapped.set(value: value, for: key) }
    }

    func set(value: Int, for key: String) {
        synchronised { wrapped.set(value: value, for: key) }
    }

    func set(value: Double, for key: String) {
        synchronised { wrapped.set(value: value, for: key) }
    }

    func set(value: String, for key: String) {
        synchronised { wrapped.set(value: value, for: key) }
    }

    func set(value: Data, for key: String) {
        synchronised { wrapped.set(value: value, for: key) }
    }

    func set(anyValue: Any, for key: String) {
        synchronised { wrapped.set(anyValue: anyValue, for: key) }
    }

    func bool(for key: String) -> Bool? {
        synchronised { wrapped.bool(for: key) }
    }

    func integer(for key: String) -> Int? {
        synchronised { wrapped.integer(for: key) }
    }

    func double(for key: String) -> Double? {
        synchronised { wrapped.double(for: key) }
    }

    func string(for key: String) -> String? {
        synchronised { wrapped.string(for: key) }
    }

    func data(for key: String) -> Data? {
        synchronised { wrapped.data(for: key) }
    }

    func anyValue(for key: String) -> Any? {
        synchronised { wrapped.anyValue(for: key) }
    }

    func removeValue(for key: String) {
        synchronised { wrapped.removeValue(for: key) }
    }

    func removeAll() {
        synchronised { wrapped.removeAll() }
    }
}
