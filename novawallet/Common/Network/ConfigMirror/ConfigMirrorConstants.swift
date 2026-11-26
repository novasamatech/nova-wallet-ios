import Foundation

enum ConfigMirrorConstants {
    /// How long a whole mirror attempt may take, from connecting to the last byte of the body,
    /// before the original url is read instead
    static let attemptDeadline: TimeInterval = 10

    /// The share of the caller's own timeout a mirror attempt may take at most
    static let maxRequestTimeoutShare: Double = 0.5

    /// How long the mirror is skipped after a failure that is about the mirror as a whole: a network
    /// or TLS error, a timeout, a missed deadline, a status of 500 and above or 429
    static let initialPause: TimeInterval = 60

    /// How much longer the pause gets each time the mirror fails the request that probes it after a pause
    static let pauseMultiplier: Double = 2

    static let maxPause: TimeInterval = 30 * .secondsInMinute

    /// The mirror puts it on every 200, see the client api of the config service
    static let commitHeader = "X-Config-Commit"
}
