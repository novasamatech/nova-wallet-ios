import Foundation

enum PriceChangeType {
    case increase
    case decrease
}

struct PricePeriodChangeViewModel {
    let changeType: PriceChangeType
    let text: String?
}
