import Foundation

struct WatchOnlyWallet: Decodable {
    let name: String
    let substrateAddress: AccountAddress
    let evmAddress: AccountAddress?
}
