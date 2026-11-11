import Foundation

enum PriceChangeType {
    case increase
    case decrease
}

struct PricePeriodChangeViewModel {
    let changeType: PriceChangeType
    let changeText: String?
    let percentText: String?
    let percentChangeType: PriceChangeType
    let changeDateText: String?
}
