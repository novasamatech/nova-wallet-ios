import Foundation

enum PricePeriodChangeViewModel {
    case increase(String?)
    case decrease(String?)

    var value: String? {
        switch self {
        case let .increase(text), let .decrease(text):
            return text
        }
    }
}
