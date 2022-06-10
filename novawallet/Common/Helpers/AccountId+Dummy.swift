import Foundation

extension AccountId {
    static func dummyAccountId(of size: Int) -> AccountId {
        AccountId(repeating: 0, count: size)
    }
}
