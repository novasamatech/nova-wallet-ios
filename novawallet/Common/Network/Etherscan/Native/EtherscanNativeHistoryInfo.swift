import Foundation

struct EtherscanNativeHistoryInfo: Encodable {
    let address: AccountAddress
    let page: Int
    let offset: Int
    let module: String = "account"
    let action: String = "txlist"
    let sort: String = "desc"
}
