import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    struct AccountId32Value: Encodable {
        enum CodingKeys: String, CodingKey {
            case network
            case accountId = "id"
        }

        let network: NetworkId
        @BytesCodable var accountId: AccountId
    }

    struct AccountId20Value: Encodable {
        let network: NetworkId
        @BytesCodable var key: AccountId
    }

    struct AccountIndexValue: Encodable {
        let network: NetworkId
        @StringCodable var index: UInt64
    }

    enum Junction: Encodable {
        case parachain(_ paraId: ParaId)
        case accountId32(AccountId32Value)
        case accountIndex64(AccountIndexValue)
        case accountKey20(AccountId20Value)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case onlyChild
        // TODO: support plurality

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            switch self {
            case let .parachain(paraId):
                try container.encode("Parachain")
                try container.encode(StringScaleMapper(value: paraId))
            case let .accountId32(value):
                try container.encode("AccountId32")
                try container.encode(value)
            case let .accountIndex64(value):
                try container.encode("AccountIndex64")
                try container.encode(value)
            case let .accountKey20(value):
                try container.encode("AccountKey20")
                try container.encode(value)
            case let .palletInstance(index):
                try container.encode("PalletInstance")
                try container.encode(StringScaleMapper(value: index))
            case let .generalIndex(index):
                try container.encode("GeneralIndex")
                try container.encode(StringScaleMapper(value: index))
            case let .generalKey(key):
                try container.encode("GeneralKey")
                try container.encode(BytesCodable(wrappedValue: key))
            case .onlyChild:
                try container.encode("OnlyChild")
                try container.encode(JSON.null)
            }
        }
    }

    struct Junctions: Encodable {
        let items: [Xcm.Junction]

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            if items.isEmpty {
                try container.encode("Here")
            } else {
                let xLocation = "X\(items.count)"
                try container.encode(xLocation)
            }

            if items.isEmpty {
                try container.encode(JSON.null)
            } else if items.count == 1 {
                try container.encode(items[0])
            } else {
                var jsonDict: [String: Xcm.Junction] = [:]
                for (index, item) in items.enumerated() {
                    let key = String(index)
                    jsonDict[key] = item
                }

                try container.encode(jsonDict)
            }
        }
    }
}

extension Xcm.Junctions {
    func appending(components: [Xcm.Junction]) -> Xcm.Junctions {
        Xcm.Junctions(items: items + components)
    }

    func prepending(components: [Xcm.Junction]) -> Xcm.Junctions {
        Xcm.Junctions(items: components + items)
    }

    func lastComponent() -> (Xcm.Junctions, Xcm.Junctions) {
        guard let lastJunction = items.last else {
            return (self, Xcm.Junctions(items: []))
        }

        let remaningItems = Array(items.dropLast())

        return (Xcm.Junctions(items: remaningItems), Xcm.Junctions(items: [lastJunction]))
    }
}
