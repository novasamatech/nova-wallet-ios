import Foundation
import Operation_iOS

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
        type.id + "-" + accountId.toHex()
    }

    var isNotRevoked: Bool {
        status == .new || status == .active
    }
}

extension ProxyAccountModel {
    func replacingStatus(_ newStatus: ProxyAccountModel.Status) -> ProxyAccountModel {
        .init(type: type, accountId: accountId, status: newStatus)
    }
}

extension ProxyAccountModel {
    var isNotActive: Bool {
        status == .new || status == .revoked
    }
}

extension Array where Element == ProxyAccountModel {
    var hasNotActive: Bool {
        contains { $0.isNotActive }
    }
}
