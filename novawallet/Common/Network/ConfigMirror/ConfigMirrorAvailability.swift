import Foundation

enum ConfigMirrorAttemptKind: Equatable {
    /// The mirror is in use and so is the request
    case regular
    /// The only request that asks the mirror after a pause while the others keep reading the original urls
    case probe
}

protocol ConfigMirrorAvailabilityProtocol {
    /// Says whether a request may try the mirror now: `nil` sends it to the original url.
    /// An attempt that was let in has to be finished with `endAttempt`, whatever its end is.
    func beginAttempt() -> ConfigMirrorAttemptKind?

    /// Takes what the attempt has learned about the mirror.
    /// Returns the length of the pause when the attempt has started one.
    @discardableResult
    func endAttempt(_ kind: ConfigMirrorAttemptKind, verdict: ConfigMirrorAttemptVerdict) -> TimeInterval?
}

/// Makes requests skip the mirror for a while after it turned out to be unavailable, so that
/// it is not waited for by every request. When the pause ends a single request probes the mirror:
/// its answer brings the mirror back for everyone, its failure starts a longer pause.
/// The state is kept in memory only, a launch starts with the mirror in use.
final class ConfigMirrorAvailability {
    private let initialPause: TimeInterval
    private let pauseMultiplier: Double
    private let maxPause: TimeInterval
    private let timeProvider: () -> TimeInterval

    private let mutex = NSLock()
    private var pausedUntil: TimeInterval?
    private var isProbing = false
    private var nextPause: TimeInterval

    init(
        initialPause: TimeInterval = ConfigMirrorConstants.initialPause,
        pauseMultiplier: Double = ConfigMirrorConstants.pauseMultiplier,
        maxPause: TimeInterval = ConfigMirrorConstants.maxPause,
        timeProvider: @escaping () -> TimeInterval = MonotonicClock.now
    ) {
        self.initialPause = initialPause
        self.pauseMultiplier = pauseMultiplier
        self.maxPause = maxPause
        self.timeProvider = timeProvider

        nextPause = initialPause
    }
}

extension ConfigMirrorAvailability: ConfigMirrorAvailabilityProtocol {
    func beginAttempt() -> ConfigMirrorAttemptKind? {
        mutex.lock()
        defer { mutex.unlock() }

        guard let pausedUntil else {
            return .regular
        }

        guard timeProvider() >= pausedUntil, !isProbing else {
            return nil
        }

        isProbing = true

        return .probe
    }

    func endAttempt(_ kind: ConfigMirrorAttemptKind, verdict: ConfigMirrorAttemptVerdict) -> TimeInterval? {
        mutex.lock()
        defer { mutex.unlock() }

        switch kind {
        case .regular:
            // Once a pause is on only the probe speaks for the mirror. The attempts that were let in
            // before the pause fail together with the one that started it and must not prolong it.
            guard pausedUntil == nil else {
                return nil
            }
        case .probe:
            // whatever the verdict is the slot is free: without a verdict the next request probes
            isProbing = false
        }

        switch verdict {
        case .reachable:
            pausedUntil = nil
            nextPause = initialPause

            return nil
        case .unavailable:
            return startPause()
        case .unknown:
            return nil
        }
    }
}

// MARK: Private

private extension ConfigMirrorAvailability {
    func startPause() -> TimeInterval {
        let pause = nextPause

        pausedUntil = timeProvider() + pause
        nextPause = min(pause * pauseMultiplier, maxPause)

        return pause
    }
}
