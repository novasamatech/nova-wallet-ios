import Foundation

struct DAppAuthRequest {
    let transportName: String
    let identifier: String
    let wallet: MetaAccountModel
    let origin: String?
    let dApp: String
    let dAppIcon: URL?

    let requiredChains: Set<ChainModel>
    let optionalChains: Set<ChainModel>?
    let unknownChains: Set<String>?
}

struct DAppAuthResponse {
    let approved: Bool

    let wallet: MetaAccountModel
}
