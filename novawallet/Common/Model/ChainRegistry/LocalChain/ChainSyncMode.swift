import Foundation

enum ChainSyncMode: Equatable, Codable {
    case disabled
    case light
    case full

    func enabled() -> Bool {
        self == .full || self == .light
    }
}

extension ChainSyncMode {
    func toEntityValue() -> Int16 {
        switch self {
        case .disabled:
            return 0
        case .light:
            return 1
        case .full:
            return 2
        }
    }

    init?(entityValue: Int16) {
        switch entityValue {
        case 0:
            self = .disabled
        case 1:
            self = .light
        case 2:
            self = .full
        default:
            return nil
        }
    }
}
