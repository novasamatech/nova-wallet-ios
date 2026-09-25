import Foundation
import Keystore_iOS

public final class BackendAttestationIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let storageKey: String
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

    public init(
        settingsManager: SettingsManagerProtocol,
        storageKey: String = AttestationSettingsKey.gatewayAttestationClientId
    ) {
        self.settingsManager = settingsManager
        self.storageKey = storageKey
    }
}

// MARK: - Identity protocol

extension BackendAttestationIdentity: BackendAttestationIdentityProtocol {
    public func clientId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.attestationClientId(for: storageKey) {
            return existing
        }

        guard !isCreationBlocked else {
            return nil
        }

        let created = UUID().uuidString.lowercased()
        settingsManager.setAttestationClientId(created, for: storageKey)

        return created
    }

    public func existingClientId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return settingsManager.attestationClientId(for: storageKey)
    }

    public func resetClientId(ifCurrent clientId: String) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard settingsManager.attestationClientId(for: storageKey) == clientId else {
            return
        }

        settingsManager.setAttestationClientId(nil, for: storageKey)
    }

    public func forgetClientId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.setAttestationClientId(nil, for: storageKey)
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
