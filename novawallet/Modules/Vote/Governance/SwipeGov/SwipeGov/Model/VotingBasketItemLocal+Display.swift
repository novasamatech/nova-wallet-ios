import Foundation

extension VotingBasketConvictionLocal {
    var displayValue: String {
        switch self {
        case .none:
            "0.1x"
        case .locked1x:
            "1x"
        case .locked2x:
            "2x"
        case .locked3x:
            "3x"
        case .locked4x:
            "4x"
        case .locked5x:
            "5x"
        case .locked6x:
            "6x"
        }
    }
}
