import Foundation

struct DAppAuthRequest {
    let identifier: String
    let wallet: MetaAccountModel
    let dApp: String
}

struct DAppAuthResponse {
    let approved: Bool
}
