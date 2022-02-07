import Foundation

struct OrmlTokenExtras: Codable {
    let currencyIdScale: String
    let currencyIdType: String
    let existentialDeposit: String
    let transfersEnabled: Bool?
}
