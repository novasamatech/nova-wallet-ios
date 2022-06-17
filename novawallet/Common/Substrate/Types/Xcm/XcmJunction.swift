import Foundation
import BigInt
import SubstrateSdk

extension Xcm {
    enum Junction: Encodable {
        case parachain(_ paraId: ParaId)
        case accountId32(_ network: NetworkId, accountId: AccountId)
        case accountIndex64(_ network: NetworkId, index: UInt64)
        case accountKey20(_ network: NetworkId, accountId: AccountId)
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
            case let .accountId32(network, accountId):
                try container.encode("AccountId32")
                try container.encode(network)
                try container.encode(BytesCodable(wrappedValue: accountId))
            case let .accountIndex64(network, index):
                try container.encode("AccountIndex64")
                try container.encode(network)
                try container.encode(StringScaleMapper(value: index))
            case let .accountKey20(network, accountId):
                try container.encode("AccountKey20")
                try container.encode(network)
                try container.encode(BytesCodable(wrappedValue: accountId))
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
            }
        }
    }

    // swiftlint:disable identifier_name
    struct Junctions: Encodable {
        let items: [Xcm.Junction]

        // swiftlint:disable:next function_body_length
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()

            if items.isEmpty {
                try container.encode("Here")
            } else {
                let xLocation = "X\(items.count)"
                try container.encode(xLocation)
            }

            try items.forEach { try container.encode($0) }
        }
    }
    // swiftlint:enable identifier_name
}

extension Xcm.Junctions {
    func appending(components: [Xcm.Junction]) -> Xcm.Junctions {
        Xcm.Junctions(items: items + components)
    }

    func prepending(components: [Xcm.Junction]) -> Xcm.Junctions {
        Xcm.Junctions(items: components + items)
    }
}
