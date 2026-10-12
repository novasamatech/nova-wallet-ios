import Foundation
import Keystore_iOS

final class NovaAuthSettingsIdentityStore: NovaAuthIdentityStoreProtocol {
    static let storageKey = "novaAuth.profile3.state.v1"
    private static let resetMarker = Data(#"{"version":1,"resetPending":true}"#.utf8)
    private let settingsManager: SettingsManagerProtocol
    private let commit: () throws -> Void
    private let mutex = NSLock()

    init(settingsManager: SettingsManagerProtocol, commit: @escaping () throws -> Void) {
        self.settingsManager = settingsManager
        self.commit = commit
    }

    static func commitStandardSettings(_ settingsManager: SettingsManagerProtocol) throws {
        // Only this singleton is known to write the standard defaults database.
        guard settingsManager === SettingsManager.shared,
              UserDefaults.standard.synchronize() else { throw NovaAuthError.storageUnavailable }
    }

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
        try write(Self.resetMarker)
    }

    func save(_ state: NovaAuthInstallationState) throws {
        mutex.lock()
        defer { mutex.unlock() }
        do {
            try NovaAuthStoredValidation.identity(state)
            let data = try JSONEncoder().encode(state)
            guard data.count <= 16384 else { throw NovaAuthError.storageUnavailable }
            try write(data)
        } catch { throw NovaAuthError.storageUnavailable }
    }
}

private extension NovaAuthSettingsIdentityStore {
    func write(_ data: Data) throws {
        settingsManager.set(value: data, for: Self.storageKey)
        do { try commit() } catch { throw NovaAuthError.storageUnavailable }
        guard settingsManager.data(for: Self.storageKey) == data else { throw NovaAuthError.storageUnavailable }
    }
}
