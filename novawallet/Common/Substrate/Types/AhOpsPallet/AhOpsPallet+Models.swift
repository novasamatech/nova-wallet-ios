import Foundation
import SubstrateSdk

extension AhOpsPallet {
    struct ContributionKey: Hashable, JSONListConvertible {
        let blockNumber: BlockNumber
        let paraId: ParaId
        let contributor: AccountId

        init(
            blockNumber: BlockNumber,
            paraId: ParaId,
            contributor: AccountId
        ) {
            self.blockNumber = blockNumber
            self.paraId = paraId
            self.contributor = contributor
        }

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
    typealias CrowdloanReserveMapping = [ContributionKey: StringCodable<Balance>]
}

extension AhOpsPallet.ContributionKey: NMapKeyStorageKeyProtocol {
    func appendSubkey(
        to encoder: DynamicScaleEncoding,
        type: String,
        index: Int
    ) throws {
        switch index {
        case 0:
            try encoder.append(StringCodable(wrappedValue: blockNumber), ofType: type)
        case 1:
            try encoder.append(StringCodable(wrappedValue: paraId), ofType: type)
        case 2:
            try encoder.append(BytesCodable(wrappedValue: contributor), ofType: type)
        default:
            throw CommonError.dataCorruption
        }
    }
}

extension AhOpsPallet.ContributionKey {
    var rawIdentifier: String {
        [
            String(blockNumber),
            String(paraId),
            contributor.toHex()
        ].joined(with: .dash)
    }
}
