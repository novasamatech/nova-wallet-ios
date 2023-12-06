import Foundation
import RobinHood

struct ProxiedAccountModel: Hashable {
    let type: Proxy.ProxyType
    let accountId: AccountId
    let status: Status

    enum Status: String {
        case new
        case active
        case revoked
    }
}

extension ProxiedAccountModel: Identifiable {
    var identifier: String {
        type.rawValue + "-" + accountId.toHexString()
    }
}
