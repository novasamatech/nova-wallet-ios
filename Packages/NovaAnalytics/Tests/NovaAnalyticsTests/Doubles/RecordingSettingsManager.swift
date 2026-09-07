import Foundation
import Keystore_iOS

final class RecordingSettingsManager: SettingsManagerProtocol {
    struct BoolWrite: Equatable {
        let key: String
        let value: Bool
    }

    private let wrapped: SettingsManagerProtocol = InMemorySettingsManager()

    private(set) var boolWrites: [BoolWrite] = []

    func set(value: Bool, for key: String) {
        boolWrites.append(BoolWrite(key: key, value: value))
        wrapped.set(value: value, for: key)
    }

    func set(value: Int, for key: String) {
        wrapped.set(value: value, for: key)
    }

    func set(value: Double, for key: String) {
        wrapped.set(value: value, for: key)
    }

    func set(value: String, for key: String) {
        wrapped.set(value: value, for: key)
    }

    func set(value: Data, for key: String) {
        wrapped.set(value: value, for: key)
    }

    func set(anyValue: Any, for key: String) {
        wrapped.set(anyValue: anyValue, for: key)
    }

    func bool(for key: String) -> Bool? {
        wrapped.bool(for: key)
    }

    func integer(for key: String) -> Int? {
        wrapped.integer(for: key)
    }

    func double(for key: String) -> Double? {
        wrapped.double(for: key)
    }

    func string(for key: String) -> String? {
        wrapped.string(for: key)
    }

    func data(for key: String) -> Data? {
        wrapped.data(for: key)
    }

    func anyValue(for key: String) -> Any? {
        wrapped.anyValue(for: key)
    }

    func removeValue(for key: String) {
        wrapped.removeValue(for: key)
    }

    func removeAll() {
        wrapped.removeAll()
    }
}
