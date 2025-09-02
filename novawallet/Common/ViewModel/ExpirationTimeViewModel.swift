import Foundation
import Foundation_iOS

enum ExpirationTimeViewModel {
    case normal(time: String)
    case expiring(time: String)
    case expired
}

protocol ExpirationViewModelFactoryProtocol {
    func createViewModel(from remainedTime: TimeInterval) throws -> ExpirationTimeViewModel
}

final class TxExpirationViewModelFactory: ExpirationViewModelFactoryProtocol {
    let expiringTreshold: TimeInterval
    let timeFormatter: TimeFormatterProtocol

    init(
        expiringTreshold: TimeInterval = 60.0,
        timeFormatter: TimeFormatterProtocol = TotalTimeFormatter()
    ) {
        self.expiringTreshold = expiringTreshold
        self.timeFormatter = timeFormatter
    }

    func createViewModel(from remainedTime: TimeInterval) throws -> ExpirationTimeViewModel {
        if remainedTime > expiringTreshold {
            let time = try timeFormatter.string(from: remainedTime)
            return .normal(time: time)
        } else if remainedTime > 0 {
            let time = try timeFormatter.string(from: remainedTime)
            return .expiring(time: time)
        } else {
            return .expired
        }
    }
}
