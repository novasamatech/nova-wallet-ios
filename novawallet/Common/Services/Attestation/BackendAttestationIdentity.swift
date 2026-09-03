import Foundation
import Keystore_iOS

/// Per gateway URL and per consent cycle: the gateway's lookup key for the registered
/// credential, so two installs never share one and a re-consented user is a new client.
final class BackendAttestationIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    /// See `AnalyticsIdentity.isCreationBlocked`: an attestation chain still executing
    /// during opt-out would otherwise mint a client id, attest a fresh key and register
    /// it with the gateway after the user opted out.
    private var isCreationBlocked: Bool = false

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - BackendAttestationIdentityProtocol

extension BackendAttestationIdentity: BackendAttestationIdentityProtocol {
    /// `nil` once forgotten and not re-armed: the caller must fail the request rather than
    /// register a new client for an opted-out install.
    func clientId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.gatewayAttestationClientId {
            return existing
        }

        guard !isCreationBlocked else {
            return nil
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
        isCreationBlocked = true
    }

    func allowCreation() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isCreationBlocked = false
    }
}
