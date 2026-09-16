import Foundation
import Keystore_iOS
import Operation_iOS

public final class AnalyticsConsentManager {
    private struct ObserverWrapper {
        weak var owner: AnyObject?
        let closure: (Bool, Bool) -> Void
        let queue: DispatchQueue?
    }

    private struct Transition {
        let oldState: Bool
        let newState: Bool
        let recipients: [ObserverWrapper]
    }

    private let settingsManager: SettingsManagerProtocol
    private let availabilityProvider: AnalyticsAvailabilityProviderProtocol
    private let mutex = NSLock()

    private var observers: [ObserverWrapper] = []
    private var pendingTransitions: [Transition] = []
    private var isNotifying = false
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
    func drainTransitions() {
        while true {
            mutex.lock()

            guard !pendingTransitions.isEmpty else {
                isNotifying = false
                mutex.unlock()

                return
            }

            let transition = pendingTransitions.removeFirst()
            mutex.unlock()

            transition.recipients.forEach { wrapper in
                guard wrapper.owner != nil else {
                    return
                }

                dispatchInQueueWhenPossible(wrapper.queue) {
                    wrapper.closure(transition.oldState, transition.newState)
                }
            }
        }
    }
}

// MARK: - AnalyticsConsentManagerProtocol

extension AnalyticsConsentManager: AnalyticsConsentManagerProtocol {
    public var isEnabled: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return state
    }

    public var isAvailable: Bool { availabilityProvider.isAvailable }

    public var isPromptSeen: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return settingsManager.analyticsPromptSeen
    }

    public var isErasureOwed: Bool {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return settingsManager.isAnalyticsErasureOwed
    }

    // Persist the wipe obligation before consent withdrawal so interruption cannot skip erasure.
    public func setEnabled(_ enabled: Bool) {
        mutex.lock()

        let oldState = state

        if oldState, !enabled {
            settingsManager.isAnalyticsErasureOwed = true
        }

        settingsManager.isAnalyticsEnabled = enabled
        state = enabled

        guard oldState != enabled else {
            mutex.unlock()
            return
        }

        observers = observers.filter { $0.owner !== nil }
        pendingTransitions.append(Transition(oldState: oldState, newState: enabled, recipients: observers))

        // Reentrant and concurrent changes wait until the current transition's notifications are dispatched.
        guard !isNotifying else {
            mutex.unlock()
            return
        }

        isNotifying = true
        mutex.unlock()

        drainTransitions()
    }

    public func setErasureOwed(_ owed: Bool) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.isAnalyticsErasureOwed = owed
    }

    public func markPromptSeen() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        settingsManager.analyticsPromptSeen = true
    }

    public func addObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool, Bool) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observers.append(ObserverWrapper(owner: owner, closure: closure, queue: queue))

        observers = observers.filter { $0.owner !== nil }
    }

    public func removeObserver(by owner: AnyObject) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        observers = observers.filter { $0.owner !== owner && $0.owner !== nil }
    }

    public func addAvailabilityObserver(
        with owner: AnyObject,
        queue: DispatchQueue?,
        closure: @escaping (Bool) -> Void
    ) {
        availabilityProvider.addObserver(with: owner, queue: queue, closure: closure)
    }

    public func removeAvailabilityObserver(by owner: AnyObject) {
        availabilityProvider.removeObserver(by: owner)
    }
}
