import Foundation
import Operation_iOS

extension DelegatedAccount {
    struct ProxyAccountModel: DelegatedAccountProtocol {
        let type: Proxy.ProxyType
        let accountId: AccountId
        let status: Status
    }
}

extension DelegatedAccount.ProxyAccountModel: Identifiable {
    var identifier: String {
        type.id + "-" + accountId.toHex()
    }

    var isNotRevoked: Bool {
        status == .new || status == .active
    }

    var isRevoked: Bool {
        status == .revoked
    }
}

extension DelegatedAccount.ProxyAccountModel {
    func replacingStatus(
        _ newStatus: DelegatedAccount.Status
    ) -> DelegatedAccount.ProxyAccountModel {
        .init(type: type, accountId: accountId, status: newStatus)
    }
}

extension DelegatedAccount.ProxyAccountModel {
    var isNotActive: Bool {
        status == .new || status == .revoked
    }
}

extension Array where Element: DelegatedAccountProtocol {
    var hasNotActive: Bool {
        contains { $0.status == .new || $0.status == .revoked }
    }
}
