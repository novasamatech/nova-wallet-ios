import Foundation

struct EtherscanHistoryInfo: Encodable {
    let address: AccountAddress
    let contractaddress: AccountAddress
    let page: Int
    let offset: Int
    let module: String = "account"
    let action: String = "tokentx"
    let sort: String = "desc"
}
