import Foundation

enum PriceChangeType {
    case increase
    case decrease
}

struct PricePeriodChangeViewModel {
    let changeType: PriceChangeType
    let changeText: String?
    let changeDateText: String?
}
