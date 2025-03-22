import Foundation

extension Xcm.VersionedMultilocation {
    var accountId: AccountId? {
        switch self {
        case let .V1(multilocation), let .V2(multilocation):
            return multilocation.accountId
        case let .V3(multilocation):
            return multilocation.accountId
        case let .V4(multilocation):
            return multilocation.accountId
        }
    }
}

extension Xcm.Multilocation {
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
