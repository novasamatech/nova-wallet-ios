import Foundation

struct DAppAuthRequest {
    let transportName: String
    let identifier: String
    let wallet: MetaAccountModel
    let origin: String?
    let dApp: String
    let dAppIcon: URL?
}

struct DAppAuthResponse {
    let approved: Bool
}
