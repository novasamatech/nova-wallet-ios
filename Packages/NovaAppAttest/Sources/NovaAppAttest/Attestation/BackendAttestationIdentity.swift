import Foundation
import Keystore_iOS

/// Per gateway URL and per consent cycle: the gateway's lookup key for the registered
/// credential, so two installs never share one and a re-consented user is a new client.
public final class BackendAttestationIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    /// Set by `forgetClientId()`, cleared only by `allowCreation()`. Cancelling an
    /// attestation chain cannot stop one that is already executing, so without this latch a
    /// chain still in flight during opt-out would call `clientId()`, find the id deleted and
    /// mint a replacement — attesting a fresh key and registering it with the gateway for an
    /// install that has just opted out. A consumer that keeps its own identifier alongside
    /// this one needs the same latch on it, and must drive both from one consent decision.
    private var isCreationBlocked: Bool = false

    /// Bumped on every consent-cycle boundary. The attestation chain captures it beside the
    /// client id and re-compares it — as a plain integer, never through `clientId()`, which
    /// mints — before the register POST, before either row write and before the attested-key
    /// cache is repopulated. Using the accessor as that predicate instead would write a new
    /// id during an opt-out→re-consent race and then register under the old one.
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
    /// `nil` once forgotten and not re-armed: the caller must fail the request rather than
    /// register a new client for an opted-out install.
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
