import Foundation
import Keystore_iOS

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

// MARK: - Identity protocol

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

    public func resetClientId(ifCurrent clientId: String) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard settingsManager.gatewayAttestationClientId == clientId else {
            return
        }

        settingsManager.gatewayAttestationClientId = nil
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
