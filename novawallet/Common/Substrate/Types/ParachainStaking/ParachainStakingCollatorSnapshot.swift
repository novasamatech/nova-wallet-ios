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

    struct CollatorSnapshot: Equatable {
        let bond: BigUInt
        let delegations: [Bond]
        let total: BigUInt
    }
}

// MARK: - Codable (handles both Moonbeam and EWX field names)

extension ParachainStaking.CollatorSnapshot: Codable {
    /// Moonbeam encodes the bonds list under `delegations`. EWX (AvN fork)
    /// encodes the same list under `nominations`. The SCALE layout is
    /// identical (`{bond: u128, vec<Bond>, total: u128}`) — only the
    /// outer JSON key differs after the runtime-metadata-driven decode.
    /// Same pattern as `ParachainStaking.Delegator` and `CandidateMetadata`.
    private enum CodingKeys: String, CodingKey {
        case bond
        case total

        // Moonbeam field name
        case delegations

        // EWX (AvN) field name
        case nominations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        bond = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .bond).value
        total = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .total).value

        if let bonds = try? container.decode([ParachainStaking.Bond].self, forKey: .delegations) {
            delegations = bonds
        } else {
            delegations = try container.decode([ParachainStaking.Bond].self, forKey: .nominations)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(StringScaleMapper(value: bond), forKey: .bond)
        try container.encode(StringScaleMapper(value: total), forKey: .total)
        try container.encode(delegations, forKey: .delegations)
    }
}
