import Foundation
import Keystore_iOS

/// The gateway's client identifier, minted per install and per consent cycle.
public final class BackendAttestationIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    private var isCreationBlocked: Bool = false

    private var currentConsentEpoch: Int = 0

    public var consentEpoch: Int {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentConsentEpoch
    }

    public init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - BackendAttestationIdentityProtocol

extension BackendAttestationIdentity: BackendAttestationIdentityProtocol {
    public func clientId() -> String? {
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

    public func existingClientId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return settingsManager.gatewayAttestationClientId
    }

    public func forgetClientId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.gatewayAttestationClientId = nil
        isCreationBlocked = true
        currentConsentEpoch += 1
    }

    public func allowCreation() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isCreationBlocked = false
        currentConsentEpoch += 1
    }
}
