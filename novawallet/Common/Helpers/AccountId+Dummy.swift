import Foundation

extension AccountId {
    static func zeroAccountId(of size: Int) -> AccountId {
        AccountId(repeating: 0, count: size)
    }
}
