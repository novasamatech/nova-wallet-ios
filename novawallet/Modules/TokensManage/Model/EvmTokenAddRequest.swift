import Foundation

struct EvmTokenAddRequest {
    let contractAddress: AccountAddress
    let name: String?
    let symbol: String
    let decimals: UInt8
    let priceIdUrl: String?
}
