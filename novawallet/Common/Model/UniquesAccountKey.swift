import Foundation
import SubstrateSdk

struct UniquesAccountKey: JSONListConvertible {
    let accountId: AccountId
    let classId: UInt32
    let instanceId: UInt32

    init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
        let expectedFieldsCount = 3
        let actualFieldsCount = jsonList.count
        guard expectedFieldsCount == actualFieldsCount else {
            throw JSONListConvertibleError.unexpectedNumberOfItems(
                expected: expectedFieldsCount,
                actual: actualFieldsCount
            )
        }

        accountId = try jsonList[0].map(to: AccountId.self, with: context)
        classId = try jsonList[1].map(to: StringScaleMapper<UInt32>.self, with: context).value
        instanceId = try jsonList[2].map(to: StringScaleMapper<UInt32>.self, with: context).value
    }
}
