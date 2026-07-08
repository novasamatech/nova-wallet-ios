import Foundation
import SubstrateSdk
import BigInt

extension ParachainStaking {
    struct Delegator: Equatable {
        let delegations: [ParachainStaking.Bond]
        let total: BigUInt
        let lessTotal: BigUInt

        var staked: BigUInt {
            total >= lessTotal ? total - lessTotal : 0
        }

        func collators() -> [AccountId] {
            delegations.map(\.owner)
        }

        func delegationsDict() -> [AccountId: ParachainStaking.Bond] {
            delegations.reduce(into: [AccountId: ParachainStaking.Bond]()) {
                $0[$1.owner] = $1
            }
        }
    }

    struct ScheduledRequest: Equatable {
        /// Account that scheduled the request. On older Moonbeam pallets this
        /// field was named `delegator`; on EWX (AvN fork) it's `nominator`.
        /// Some pallet versions omit it entirely (the request is implicitly
        /// keyed by the iterating delegator). Optional in all cases.
        var delegator: BytesCodable?
        let whenExecutable: RoundIndex
        let action: DelegationAction
    }

    enum DelegationAction: Decodable, Encodable, Equatable {
        static let revokeField = "Revoke"
        static let decreaseField = "Decrease"

        case revoke(amount: BigUInt)
        case decrease(amount: BigUInt)

        public init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            let type = try container.decode(String.self)
            let amount = try container.decode(StringScaleMapper<BigUInt>.self).value

            switch type {
            case Self.revokeField:
                self = .revoke(amount: amount)
            case Self.decreaseField:
                self = .decrease(amount: amount)
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unexpected type"
                )
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .revoke(amount):
                try container.encode(Self.revokeField)
                try container.encode(StringScaleMapper(value: amount))
            case let .decrease(amount):
                try container.encode(Self.decreaseField)
                try container.encode(StringScaleMapper(value: amount))
            }
        }
    }
}

// MARK: - ScheduledRequest Codable (dual-decode delegator ↔ nominator)

extension ParachainStaking.ScheduledRequest: Codable {
    private enum CodingKeys: String, CodingKey {
        case whenExecutable
        case action

        // Moonbeam (legacy)
        case delegator

        // EWX (AvN fork)
        case nominator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        whenExecutable = try container
            .decode(StringScaleMapper<ParachainStaking.RoundIndex>.self, forKey: .whenExecutable).value
        action = try container.decode(ParachainStaking.DelegationAction.self, forKey: .action)

        if let value = try container.decodeIfPresent(BytesCodable.self, forKey: .delegator) {
            delegator = value
        } else if let value = try container.decodeIfPresent(BytesCodable.self, forKey: .nominator) {
            delegator = value
        } else {
            delegator = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(delegator, forKey: .delegator)
        try container.encode(StringScaleMapper(value: whenExecutable), forKey: .whenExecutable)
        try container.encode(action, forKey: .action)
    }
}

// MARK: - Codable (handles both Moonbeam and EWX field names)

extension ParachainStaking.Delegator: Codable {
    /// Moonbeam encodes the bonds list under the field name `delegations`.
    /// EWX (AvN fork) encodes the same list under `nominations`.
    /// The shape of each bond is identical — only the outer field name differs.
    private enum CodingKeys: String, CodingKey {
        case total
        case lessTotal

        // Moonbeam field name
        case delegations

        // EWX (AvN) field name
        case nominations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let bonds = try? container.decode([ParachainStaking.Bond].self, forKey: .delegations) {
            delegations = bonds
        } else {
            delegations = try container.decode([ParachainStaking.Bond].self, forKey: .nominations)
        }

        total = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .total).value
        lessTotal = try container.decode(StringScaleMapper<BigUInt>.self, forKey: .lessTotal).value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(delegations, forKey: .delegations)
        try container.encode(StringScaleMapper(value: total), forKey: .total)
        try container.encode(StringScaleMapper(value: lessTotal), forKey: .lessTotal)
    }
}
