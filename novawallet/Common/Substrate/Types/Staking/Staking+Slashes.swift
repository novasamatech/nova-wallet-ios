import Foundation
import SubstrateSdk

extension Staking {
    struct SlashingSpans: Decodable {
        @StringCodable var lastNonzeroSlash: UInt32
        let prior: [StringScaleMapper<UInt32>]
    }

    struct UnappliedSlash: Decodable {
        @BytesCodable var validator: AccountId
    }

    struct UnappliedSlashSyncKey: JSONListConvertible, Hashable {
        let era: EraIndex

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 1
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            era = try jsonList[0].map(to: StringScaleMapper.self, with: context).value
        }
    }

    struct UnappliedSlashAsyncKey: JSONListConvertible, Hashable {
        let era: EraIndex
        let validator: AccountId
        let fraction: Perbill
        let page: UInt32

        init(jsonList: [JSON], context: [CodingUserInfoKey: Any]?) throws {
            let expectedFieldsCount = 2
            let actualFieldsCount = jsonList.count
            guard expectedFieldsCount == actualFieldsCount else {
                throw JSONListConvertibleError.unexpectedNumberOfItems(
                    expected: expectedFieldsCount,
                    actual: actualFieldsCount
                )
            }

            era = try jsonList[0].map(to: StringScaleMapper.self, with: context).value

            guard let tuple = jsonList[1].arrayValue, tuple.count == 3 else {
                throw JSONListConvertibleError.unexpectedValue(jsonList[1])
            }

            validator = try tuple[0].map(to: BytesCodable.self, with: context).wrappedValue
            fraction = try tuple[1].map(to: StringScaleMapper.self, with: context).value
            page = try tuple[1].map(to: StringScaleMapper.self, with: context).value
        }
    }
}

extension Staking.SlashingSpans {
    var numOfSlashingSpans: UInt32 {
        UInt32(prior.count) + 1
    }
}
