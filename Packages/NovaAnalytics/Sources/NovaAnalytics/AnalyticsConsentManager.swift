import Foundation
import Keystore_iOS
import Operation_iOS

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

    public func setEnabled(_ enabled: Bool) {
        settingsManager.isAnalyticsEnabled = enabled

        let oldState = state
        state = enabled

        guard oldState != enabled else {
            return
        }

        notify(oldState: oldState, newState: enabled)
    }

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
