import Foundation

enum PayCardStatus {
    case pending(remained: TimeInterval, total: TimeInterval)
    case created
    case failed

    var isCreated: Bool {
        switch self {
        case .pending, .failed:
            false
        case .created:
            true
        }
    }
}
