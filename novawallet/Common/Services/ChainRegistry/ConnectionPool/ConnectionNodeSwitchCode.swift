import Foundation

enum ConnectionNodeSwitchCode {
    static let infura = -32005
    static let alchemy = 429
    static let blustCapacity = -32098
    static let blustRateLimit = -32097

    static var allCodes: Set<Int> {
        [Self.infura, Self.alchemy, Self.blustCapacity, Self.blustRateLimit]
    }
}
