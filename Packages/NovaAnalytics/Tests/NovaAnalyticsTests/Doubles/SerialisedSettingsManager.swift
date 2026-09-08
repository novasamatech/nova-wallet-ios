import Foundation
import Keystore_iOS

final class SerialisedSettingsManager: SettingsManagerProtocol {
    struct BoolWrite: Equatable {
        let key: String
        let value: Bool
    }

    private let store = Locked(InMemorySettingsManager())
    private let recordedBoolWrites = Locked<[BoolWrite]>([])

    var boolWrites: [BoolWrite] { recordedBoolWrites.value }

    func set(value: Bool, for key: String) {
        recordedBoolWrites.update { $0.append(BoolWrite(key: key, value: value)) }
        store.update { $0.set(value: value, for: key) }
    }

    func set(value: Int, for key: String) {
        store.update { $0.set(value: value, for: key) }
    }

    func set(value: Double, for key: String) {
        store.update { $0.set(value: value, for: key) }
    }

    func set(value: String, for key: String) {
        store.update { $0.set(value: value, for: key) }
    }

    func set(value: Data, for key: String) {
        store.update { $0.set(value: value, for: key) }
    }

    func set(anyValue: Any, for key: String) {
        store.update { $0.set(anyValue: anyValue, for: key) }
    }

    func bool(for key: String) -> Bool? {
        store.read { $0.bool(for: key) }
    }

    func integer(for key: String) -> Int? {
        store.read { $0.integer(for: key) }
    }

    func double(for key: String) -> Double? {
        store.read { $0.double(for: key) }
    }

    func string(for key: String) -> String? {
        store.read { $0.string(for: key) }
    }

    func data(for key: String) -> Data? {
        store.read { $0.data(for: key) }
    }

    func anyValue(for key: String) -> Any? {
        store.read { $0.anyValue(for: key) }
    }

    func removeValue(for key: String) {
        store.update { $0.removeValue(for: key) }
    }

    func removeAll() {
        store.update { $0.removeAll() }
    }
}
