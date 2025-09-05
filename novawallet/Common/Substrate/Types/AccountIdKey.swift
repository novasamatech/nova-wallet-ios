import Foundation
import SubstrateSdk

struct AccountIdKey: JSONListConvertible, Hashable {
    let accountId: AccountId

    init(accountId: AccountId) {
        self.accountId = accountId
    }

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 1
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        accountId = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
    }
}
