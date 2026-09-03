import Foundation
import Keystore_iOS

/// Per gateway URL and per consent cycle: the gateway's lookup key for the registered
/// credential, so two installs never share one and a re-consented user is a new client.
final class BackendAttestationIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - BackendAttestationIdentityProtocol

extension BackendAttestationIdentity: BackendAttestationIdentityProtocol {
    func clientId() -> String {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.gatewayAttestationClientId {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        settingsManager.gatewayAttestationClientId = created

        return created
    }

    func forgetClientId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.gatewayAttestationClientId = nil
    }
}
