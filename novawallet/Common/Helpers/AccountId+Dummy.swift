import Foundation

extension AccountId {
    static func zeroAccountId(of size: Int) -> AccountId {
        AccountId(repeating: 0, count: size)
    }

    static func nonzeroAccountId(of size: Int) -> AccountId {
        AccountId(repeating: 7, count: size)
    }
}
