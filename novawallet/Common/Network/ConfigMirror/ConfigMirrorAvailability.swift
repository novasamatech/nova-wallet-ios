import Foundation

protocol ConfigMirrorAvailabilityProtocol {
    var isAvailable: Bool { get }

    /// Remembers a failed mirror attempt. Returns `true` when this failure has made the mirror unavailable.
    func registerFailure(_ error: Error) -> Bool
}

/// Makes requests skip the mirror for a while after it turned out to be unavailable, so that
/// it is not waited for by every request. When the pause ends every request tries the mirror again.
final class ConfigMirrorAvailability {
    // Errors of the device's own connectivity and a cancellation say nothing about the mirror
    private static let unrelatedErrorCodes: Set<Int> = [
        NSURLErrorCancelled,
        NSURLErrorNotConnectedToInternet,
        NSURLErrorDataNotAllowed,
        NSURLErrorInternationalRoamingOff,
        NSURLErrorCallIsActive
    ]

    private static let serverErrorStatusCode = 500

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
        guard isMirrorWide(error) else {
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

private extension ConfigMirrorAvailability {
    // A missing file or an unusable body concerns one file and is answered fast. A connection failure
    // or a server error is about the mirror as a whole, so it is worth skipping.
    func isMirrorWide(_ error: Error) -> Bool {
        if case let ConfigMirrorFailure.unexpectedStatus(statusCode?) = error {
            return statusCode >= Self.serverErrorStatusCode
        }

        let nsError = error as NSError

        return nsError.domain == NSURLErrorDomain && !Self.unrelatedErrorCodes.contains(nsError.code)
    }
}
