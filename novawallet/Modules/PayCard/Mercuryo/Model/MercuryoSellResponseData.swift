import Foundation

struct MercuryoRampResponseData: Decodable {
    let status: MercuryoStatus
    let amounts: MercuryoAmounts
    let address: AccountAddress
}

struct MercuryoAmounts: Decodable {
    let request: MercuryoAmount
}

struct MercuryoAmount: Decodable {
    let amount: AmountDecimal
    let currency: String
}
