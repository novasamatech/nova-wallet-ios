import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    enum NetworkId: Equatable, Codable {
        static let anyField = "Any"
        static let namedField = "Named"
        static let polkadotField = "Polkadot"
        static let kusamaField = "Kusama"

        case any
        case named(_ data: Data)
        case polkadot
        case kusama

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            switch type {
            case Self.anyField:
                self = .any
            case Self.namedField:
                let data = try container.decode(BytesCodable.self).wrappedValue
                self = .named(data)
            case Self.polkadotField:
                self = .polkadot
            case Self.kusamaField:
                self = .kusama
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
            case .any:
                try container.encode(Self.anyField)
                try container.encode(JSON.null)
            case let .named(data):
                try container.encode(Self.namedField)
                try container.encode(BytesCodable(wrappedValue: data))
            case .polkadot:
                try container.encode(Self.polkadotField)
                try container.encode(JSON.null)
            case .kusama:
                try container.encode(Self.kusamaField)
                try container.encode(JSON.null)
            }
        }
    }

    struct AccountId32Value: Equatable, Codable {
        enum CodingKeys: String, CodingKey {
            case network
            case accountId = "id"
        }

        let network: NetworkId
        @BytesCodable var accountId: AccountId
    }

    struct AccountId20Value: Equatable, Codable {
        let network: NetworkId
        @BytesCodable var key: AccountId
    }

    struct AccountIndexValue: Equatable, Codable {
        let network: NetworkId
        @StringCodable var index: UInt64
    }

    enum Junction: Equatable, Codable {
        static let parachainField = "Parachain"
        static let accountId32Field = "AccountId32"
        static let accountIndex64Field = "AccountIndex64"
        static let accountKey20Field = "AccountKey20"
        static let palletInstanceField = "PalletInstance"
        static let generalIndexField = "GeneralIndex"
        static let generalKeyField = "GeneralKey"
        static let onlyChildKey = "OnlyChild"

        case parachain(_ paraId: ParaId)
        case accountId32(AccountId32Value)
        case accountIndex64(AccountIndexValue)
        case accountKey20(AccountId20Value)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case onlyChild

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
            case Self.generalIndexField:
                let index = try container.decode(StringScaleMapper<BigUInt>.self).value
                self = .generalIndex(index)
            case Self.generalKeyField:
                let key = try container.decode(BytesCodable.self).wrappedValue
                self = .generalKey(key)
            case Self.onlyChildKey:
                self = .onlyChild
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
            }
        }
    }

    enum JunctionsConstants {
        static let hereField = "Here"
        static let junctionPrefix = "X"
    }

    struct Junctions<J>: Equatable, Codable where J: Equatable & Codable {
        let items: [J]

        init(items: [J]) {
            self.items = items
        }

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()

            let type = try container.decode(String.self)

            if type == JunctionsConstants.hereField {
                items = []
            } else if
                type.count == 2,
                type.starts(with: JunctionsConstants.junctionPrefix),
                let itemsCount = Int(type.suffix(1)) {
                if itemsCount == 1 {
                    let item = try container.decode(J.self)
                    items = [item]
                } else {
                    let dict = try container.decode([String: J].self)

                    items = try (0 ..< itemsCount).map { index in
                        guard let junction = dict[String(index)] else {
                            throw DecodingError.dataCorrupted(
                                .init(
                                    codingPath: container.codingPath,
                                    debugDescription: "Unsupported junctions: \(dict)"
                                )
                            )
                        }

                        return junction
                    }
                }
            } else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: container.codingPath,
                        debugDescription: "Unsupported junctions format"
                    )
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            if items.isEmpty {
                try container.encode(JunctionsConstants.hereField)
            } else {
                let xLocation = "\(JunctionsConstants.junctionPrefix)\(items.count)"
                try container.encode(xLocation)
            }

            if items.isEmpty {
                try container.encode(JSON.null)
            } else if items.count == 1 {
                try container.encode(items[0])
            } else {
                var jsonDict: [String: J] = [:]
                for (index, item) in items.enumerated() {
                    let key = String(index)
                    jsonDict[key] = item
                }

                try container.encode(jsonDict)
            }
        }
    }

    typealias JunctionsV2 = Junctions<Junction>
}

extension Xcm.Junctions {
    func appending(components: [J]) -> Xcm.Junctions<J> {
        Xcm.Junctions(items: items + components)
    }

    func prepending(components: [J]) -> Xcm.Junctions<J> {
        Xcm.Junctions(items: components + items)
    }

    func lastComponent() -> (Xcm.Junctions<J>, Xcm.Junctions<J>) {
        guard let lastJunction = items.last else {
            return (self, Xcm.Junctions(items: []))
        }

        let remaningItems = Array(items.dropLast())

        return (Xcm.Junctions(items: remaningItems), Xcm.Junctions(items: [lastJunction]))
    }
}
