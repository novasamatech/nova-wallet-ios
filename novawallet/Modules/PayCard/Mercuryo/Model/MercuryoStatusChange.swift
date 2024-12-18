import Foundation

struct MercuryoStatusChange: Decodable {
    let id: String
    let amount: AmountDecimal
    let type: String?
    let currency: String
    let network: String
    let status: String
}

enum MercuryoStatus: String, Decodable {
    case new
    case pending
    case succeeded
    case failed
}

enum MercuryoStatusType: String {
    case deposit
    case fiatCardSell = "fiat_card_sell"
}
