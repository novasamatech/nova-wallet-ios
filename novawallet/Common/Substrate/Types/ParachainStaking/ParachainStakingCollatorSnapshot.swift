import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct Bond: Equatable, Codable {
        @BytesCodable var owner: AccountId
        @StringCodable var amount: BigUInt
    }

    struct CollatorSnapshotKey: JSONListConvertible {
        let accountId: AccountId
        let roundIndex: RoundIndex

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            roundIndex = try jsonList[0].map(to: StringScaleMapper<RoundIndex>.self, with: context).value
            accountId = try jsonList[1].map(to: BytesCodable.self, with: context).wrappedValue
        }
    }

    struct CollatorSnapshot: Equatable, Codable {
        @StringCodable var bond: BigUInt

        let delegations: [Bond]

        @StringCodable var total: BigUInt
    }
}
