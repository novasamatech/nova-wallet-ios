import Foundation

struct MercuryoTransferData: Decodable {
    let id: String
    let flowId: String
    let amount: AmountDecimal
    let currency: String
    let network: String
    let address: AccountAddress

    enum CodingKeys: String, CodingKey {
        case id
        case flowId = "flow_id"
        case amount
        case currency
        case network
        case address
    }
}
