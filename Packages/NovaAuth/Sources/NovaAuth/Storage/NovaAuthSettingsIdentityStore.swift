import Foundation
import Keystore_iOS

final class NovaAuthSettingsIdentityStore: NovaAuthIdentityStoreProtocol {
    static let storageKey = "novaAuth.profile3.state.v1"
    private static let resetMarker = Data(#"{"version":1,"resetPending":true}"#.utf8)
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    init(settingsManager: SettingsManagerProtocol) { self.settingsManager = settingsManager }

    func load() throws -> NovaAuthInstallationState? {
        mutex.lock()
        defer { mutex.unlock() }
        guard let raw = settingsManager.anyValue(for: Self.storageKey) else { return nil }
        guard let data = raw as? Data, data.count <= 16384 else { throw NovaAuthIdentityStoreError.corrupt }
        if data == Self.resetMarker { throw NovaAuthIdentityStoreError.resetPending }
        do {
            let state = try JSONDecoder().decode(NovaAuthInstallationState.self, from: data)
            try NovaAuthStoredValidation.identity(state)
            return state
        } catch { throw NovaAuthIdentityStoreError.corrupt }
    }

    func markResetPending() throws {
        mutex.lock()
        defer { mutex.unlock() }
        settingsManager.set(value: Self.resetMarker, for: Self.storageKey)
        guard settingsManager.data(for: Self.storageKey) == Self.resetMarker else {
            throw NovaAuthError.storageUnavailable
        }
    }

    func save(_ state: NovaAuthInstallationState) throws {
        mutex.lock()
        defer { mutex.unlock() }
        do {
            try NovaAuthStoredValidation.identity(state)
            let data = try JSONEncoder().encode(state)
            guard data.count <= 16384 else { throw NovaAuthError.storageUnavailable }
            settingsManager.set(value: data, for: Self.storageKey)
            guard settingsManager.data(for: Self.storageKey) == data else { throw NovaAuthError.storageUnavailable }
        } catch { throw NovaAuthError.storageUnavailable }
    }
}
