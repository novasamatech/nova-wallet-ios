import Foundation

struct TransakTransferEventData: Decodable {
    let cryptoAmount: AmountDecimal
    let walletAddress: String
}
