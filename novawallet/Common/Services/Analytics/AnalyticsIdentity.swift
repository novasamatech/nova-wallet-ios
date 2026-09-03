import Foundation
import Keystore_iOS

final class AnalyticsIdentity {
    private let settingsManager: SettingsManagerProtocol
    private let mutex = NSLock()

    /// Set by `forgetInstallId()` and cleared only when consent is granted again.
    /// `flushCallStore.cancel()` cannot stop an upload chain that is already executing
    /// (`OperationCombiningService.cancel()` is a no-op), so without this latch a chain
    /// still in flight during opt-out would call `installId()`, find the key deleted, and
    /// mint a replacement — leaving an opted-out install holding an identifier.
    private var isCreationBlocked: Bool = false

    /// One per instance, therefore one per process. An iOS process can span days;
    /// the id is still per process (parity with Android). Rotated on re-consent, because a
    /// session id shared across an opt-out would let the gateway join the old install id to
    /// the new one and undo the point of minting a new one.
    private var currentSessionId: String = UUID().uuidString.lowercased()

    var sessionId: String {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return currentSessionId
    }

    init(settingsManager: SettingsManagerProtocol) {
        self.settingsManager = settingsManager
    }
}

// MARK: - AnalyticsIdentityProtocol

extension AnalyticsIdentity: AnalyticsIdentityProtocol {
    /// Created on first call — which happens inside the flush path, behind the consent
    /// guard — and never before. `nil` once the id has been forgotten and consent has not
    /// been granted again: the caller must abandon the upload rather than mint a new one.
    func installId() -> String? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let existing = settingsManager.analyticsInstallId {
            return existing
        }

        guard !isCreationBlocked else {
            return nil
        }

        let created = UUID().uuidString.lowercased()
        settingsManager.analyticsInstallId = created

        return created
    }

    /// A delete, never a rotation: an opted-out install has no id at all.
    func forgetInstallId() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.analyticsInstallId = nil
        isCreationBlocked = true
    }

    /// Called on the consent false to true edge, so a re-consented user gets a new id.
    func allowCreation() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        isCreationBlocked = false
        currentSessionId = UUID().uuidString.lowercased()
    }
}
