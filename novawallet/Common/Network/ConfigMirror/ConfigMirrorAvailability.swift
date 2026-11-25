import Foundation

protocol ConfigMirrorAvailabilityProtocol {
    var isAvailable: Bool { get }

    /// Remembers a failed mirror attempt. Returns `true` when this failure has made the mirror unavailable.
    func registerFailure(_ error: Error) -> Bool
}

extension ConfigMirrorAvailabilityProtocol {
    func reportFailure(_ error: Error, for mirrorURL: URL, logger: LoggerProtocol) {
        logger.warning("Config mirror failed for \(mirrorURL.path), reading the original url: \(error)")

        if registerFailure(error) {
            logger.warning("Config mirror can't be reached, skipping it until the cool-down ends")
        }
    }
}

/// Makes files and images skip the mirror for a while after it could not be reached,
/// so that an unreachable mirror is waited for once and not by every request.
final class ConfigMirrorAvailability {
    static let shared = ConfigMirrorAvailability()

    private let cooldown: TimeInterval
    private let uptimeClosure: () -> TimeInterval

    private let mutex = NSLock()
    private var unavailableUntil: TimeInterval?

    // The uptime is used instead of the date for the cool-down not to depend on the device clock changes
    init(
        cooldown: TimeInterval = ConfigMirrorConstants.unavailabilityCooldown,
        uptimeClosure: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.cooldown = cooldown
        self.uptimeClosure = uptimeClosure
    }
}

extension ConfigMirrorAvailability: ConfigMirrorAvailabilityProtocol {
    var isAvailable: Bool {
        mutex.lock()
        defer { mutex.unlock() }

        guard let unavailableUntil else {
            return true
        }

        return uptimeClosure() >= unavailableUntil
    }

    func registerFailure(_ error: Error) -> Bool {
        // A wrong status or body concerns one file and is answered fast, so only a connection failure counts
        guard error.isConnectionFailure else {
            return false
        }

        mutex.lock()
        defer { mutex.unlock() }

        let uptime = uptimeClosure()

        if let unavailableUntil, uptime < unavailableUntil {
            return false
        }

        unavailableUntil = uptime + cooldown

        return true
    }
}

private extension Error {
    var isConnectionFailure: Bool {
        let nsError = self as NSError

        return nsError.domain == NSURLErrorDomain && nsError.code != NSURLErrorCancelled
    }
}
