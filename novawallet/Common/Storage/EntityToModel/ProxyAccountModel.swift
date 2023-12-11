import Foundation
import RobinHood

struct ProxyAccountModel: Hashable {
    let type: Proxy.ProxyType
    let accountId: AccountId
    let status: Status

    enum Status: String, CaseIterable {
        case new
        case active
        case revoked
    }
}

extension ProxyAccountModel: Identifiable {
    var identifier: String {
        type.id + "-" + accountId.toHexString()
    }
}
