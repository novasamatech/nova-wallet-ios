import Foundation

extension XcmV3.Multilocation {
    var accountId: AccountId? {
        switch interior.items.last {
        case let .accountId32(account):
            return account.accountId
        case let .accountKey20(account):
            return account.key
        default:
            return nil
        }
    }
}
