import Foundation
import Keystore_iOS

/// Serialises every call into a wrapped `SettingsManagerProtocol` behind an `NSLock`.
///
/// `InMemorySettingsManager` holds a bare unguarded `[String: Any]` (Keystore-iOS
/// `InMemorySettingsManager.swift:4`), so any test that lets two threads reach one instance
/// crashes in `Dictionary` rather than failing its own assertion. Distinct keys do not make
/// a `Dictionary` thread-safe: a resize triggered by one writer moves storage under the
/// other. Wrapping the store makes every call atomic, so the only unguarded read-modify-write
/// left in a test's picture is the one that test is actually about.
///
/// A duplicate of `NovaAppAttestTests`' copy rather than a shared one: two packages' test
/// targets cannot import each other.
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
