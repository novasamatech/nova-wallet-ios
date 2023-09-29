import Foundation
import BigInt
import SubstrateSdk

extension XcmV3 {
    enum NetworkId: Codable {
        static let byGenesisField = "ByGenesis"
        static let polkadotField = "Polkadot"
        static let kusamaField = "Kusama"
        static let westendField = "Westend"

        case byGenesis(Data)
        case polkadot
        case kusama
        case westend

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case Self.byGenesisField:
                let hash = try container.decode(BytesCodable.self).wrappedValue
                self = .byGenesis(hash)
            case Self.polkadotField:
                self = .polkadot
            case Self.kusamaField:
                self = .kusama
            case Self.westendField:
                self = .westend
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported network id: \(type)"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .byGenesis(hash):
                try container.encode(Self.byGenesisField)
                try container.encode(BytesCodable(wrappedValue: hash))
            case .polkadot:
                try container.encode(Self.polkadotField)
                try container.encode(JSON.null)
            case .kusama:
                try container.encode(Self.kusamaField)
                try container.encode(JSON.null)
            case .westend:
                try container.encode(Self.westendField)
                try container.encode(JSON.null)
            }
        }
    }

    struct AccountId32Value: Codable {
        enum CodingKeys: String, CodingKey {
            case network
            case accountId = "id"
        }

        let network: NetworkId?
        @BytesCodable var accountId: AccountId
    }

    struct AccountId20Value: Codable {
        let network: NetworkId?
        @BytesCodable var key: AccountId
    }

    struct AccountIndexValue: Codable {
        let network: NetworkId?
        @StringCodable var index: UInt64
    }

    enum Junction: Codable {
        static let parachainField = "Parachain"
        static let accountId32Field = "AccountId32"
        static let accountIndex64Field = "AccountIndex64"
        static let accountKey20Field = "AccountKey20"
        static let palletInstanceField = "PalletInstance"
        static let generalIndexField = "GeneralIndex"
        static let generalKeyField = "GeneralKey"
        static let onlyChildKey = "OnlyChild"
        static let globalConsensusField = "GlobalConsensus"

        case parachain(_ paraId: ParaId)
        case accountId32(AccountId32Value)
        case accountIndex64(AccountIndexValue)
        case accountKey20(AccountId20Value)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case onlyChild
        case globalConsensus(NetworkId)

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case Self.parachainField:
                let paraId = try container.decode(StringScaleMapper<ParaId>.self).value
                self = .parachain(paraId)
            case Self.accountId32Field:
                let accountId = try container.decode(AccountId32Value.self)
                self = .accountId32(accountId)
            case Self.accountIndex64Field:
                let accountIndex = try container.decode(AccountIndexValue.self)
                self = .accountIndex64(accountIndex)
            case Self.accountKey20Field:
                let accountKey = try container.decode(AccountId20Value.self)
                self = .accountKey20(accountKey)
            case Self.palletInstanceField:
                let index = try container.decode(StringScaleMapper<UInt8>.self).value
                self = .palletInstance(index)
            case Self.generalKeyField:
                let key = try container.decode(BytesCodable.self).wrappedValue
                self = .generalKey(key)
            case Self.onlyChildKey:
                self = .onlyChild
            case Self.globalConsensusField:
                let network = try container.decode(NetworkId.self)
                self = .globalConsensus(network)
            default:
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Unsupported junction: \(type)"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .parachain(paraId):
                try container.encode(Self.parachainField)
                try container.encode(StringScaleMapper(value: paraId))
            case let .accountId32(value):
                try container.encode(Self.accountId32Field)
                try container.encode(value)
            case let .accountIndex64(value):
                try container.encode(Self.accountIndex64Field)
                try container.encode(value)
            case let .accountKey20(value):
                try container.encode(Self.accountKey20Field)
                try container.encode(value)
            case let .palletInstance(index):
                try container.encode(Self.palletInstanceField)
                try container.encode(StringScaleMapper(value: index))
            case let .generalIndex(index):
                try container.encode(Self.generalIndexField)
                try container.encode(StringScaleMapper(value: index))
            case let .generalKey(key):
                try container.encode(Self.generalKeyField)
                try container.encode(BytesCodable(wrappedValue: key))
            case .onlyChild:
                try container.encode(Self.onlyChildKey)
                try container.encode(JSON.null)
            case let .globalConsensus(network):
                try container.encode(Self.globalConsensusField)
                try container.encode(network)
            }
        }
    }

    typealias Junctions = Xcm.Junctions<XcmV3.Junction>
}
