import Foundation

enum ConfigMirrorConstants {
    /// How long a mirror attempt may wait for data before the original url is read instead
    static let attemptTimeout: TimeInterval = 5

    /// How long the mirror is skipped after it could not be reached
    static let unavailabilityCooldown: TimeInterval = 60
}
