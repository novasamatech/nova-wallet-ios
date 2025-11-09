import Foundation
import SubstrateSdk

extension AhOpsPallet {
    struct ContributionKey: Hashable, JSONListConvertible {
        let blockNumber: BlockNumber
        let paraId: ParaId
        let contributor: AccountId

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 3
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            blockNumber = try jsonList[0].map(
                to: StringCodable<BlockNumber>.self,
                with: context
            ).wrappedValue

            paraId = try jsonList[1].map(
                to: StringCodable<ParaId>.self,
                with: context
            ).wrappedValue

            contributor = try jsonList[2].map(
                to: BytesCodable.self,
                with: context
            ).wrappedValue
        }
    }

    struct Contribution: Decodable {
        let potAccountId: AccountId
        let amount: Balance

        init(from decoder: any Decoder) throws {
            var container = try decoder.unkeyedContainer()

            potAccountId = try container.decode(BytesCodable.self).wrappedValue
            amount = try container.decode(StringCodable<Balance>.self).wrappedValue
        }
    }

    typealias ContributionMapping = [ContributionKey: Contribution]
}
