import Foundation
import Keystore_iOS
import Operation_iOS

/// The app's `Observable<Bool>` supplied the observer list before this type moved into the
/// package, and it cannot come along: it is an app type used by 45 other app files, so
/// carrying it here would either fork it or drag the app's whole notification vocabulary
/// across the boundary. `addObserver`/`removeObserver` are requirements of
/// `AnalyticsConsentManagerProtocol` — package-owned — so they are satisfied here directly.
/// The semantics are the ones the observers were written against and are unchanged: owners
/// are held weakly and pruned, and a closure runs only when the flag actually flips.
public final class AnalyticsConsentManager {
    private struct ObserverWrapper {
        weak var owner: AnyObject?
        let closure: (Bool, Bool) -> Void
        let queue: DispatchQueue?
    }

    private let settingsManager: SettingsManagerProtocol
    private let availabilityProvider: AnalyticsAvailabilityProviderProtocol

    private var observers: [ObserverWrapper] = []
    private var state: Bool

    public init(
        settingsManager: SettingsManagerProtocol,
        availabilityProvider: AnalyticsAvailabilityProviderProtocol
    ) {
        self.settingsManager = settingsManager
        self.availabilityProvider = availabilityProvider

        state = settingsManager.isAnalyticsEnabled
    }
}

// MARK: - Private

private extension AnalyticsConsentManager {
    func notify(oldState: Bool, newState: Bool) {
        observers = observers.filter { $0.owner !== nil }

        observers.forEach { wrapper in
            guard wrapper.owner != nil else {
                return
            }

            dispatchInQueueWhenPossible(wrapper.queue) {
                wrapper.closure(oldState, newState)
            }
        }
    }
}

// MARK: - AnalyticsConsentManagerProtocol

extension AnalyticsConsentManager: AnalyticsConsentManagerProtocol {
    public var isEnabled: Bool { state }

    public var isAvailable: Bool { availabilityProvider.isAvailable }

    public var isPromptSeen: Bool { settingsManager.analyticsPromptSeen }

    /// Only flips the flag and notifies. The opt-out wipe belongs to `AnalyticsService`,
    /// which observes this manager: the manager owns no queue, identity or attestation.
    public func setEnabled(_ enabled: Bool) {
        settingsManager.isAnalyticsEnabled = enabled

        let oldState = state
        state = enabled

        guard oldState != enabled else {
            return
        }

        notify(oldState: oldState, newState: enabled)
    }

    /// Never cleared — re-onboarding must not re-ask; the Settings switch is the way back.
    public func markPromptSeen() {
        settingsManager.analyticsPromptSeen = true
    }

    public func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    ) {
        observers.append(ObserverWrapper(owner: owner, closure: closure, queue: queue))

        observers = observers.filter { $0.owner !== nil }
    }

    public func removeObserver(by owner: AnyObject) {
        observers = observers.filter { $0.owner !== owner && $0.owner !== nil }
    }
}
