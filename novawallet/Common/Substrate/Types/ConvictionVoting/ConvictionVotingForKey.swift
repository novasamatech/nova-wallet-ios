import Foundation
import SubstrateSdk

extension ConvictionVoting {
    struct VotingForKey: JSONListConvertible, Hashable {
        let accountId: AccountId
        let trackId: Referenda.TrackId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            accountId = try jsonList[0].map(to: BytesCodable.self, with: context).wrappedValue
            trackId = try jsonList[1].map(to: StringScaleMapper<Referenda.TrackId>.self, with: context).value
        }
    }
}
