import Foundation

enum PricePeriodChangeViewModel {
    case up(String)
    case down(String)

    var value: String {
        switch self {
        case let .up(text), let .down(text):
            return text
        }
    }
}
