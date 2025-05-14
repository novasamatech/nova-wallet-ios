import Foundation
import Operation_iOS

protocol DelegatedAccountProtocol: Hashable {
    var accountId: AccountId { get }
    var status: DelegatedAccount.Status { get }
}

enum DelegatedAccount {
    enum Status: String, CaseIterable {
        case new
        case active
        case revoked
    }
}
