import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    enum NetworkId: Equatable {
        case any
        case other(RawName, RawValue)
    }

    struct AccountId32: Equatable {
        let network: NetworkId
        let accountId: AccountId
    }

    struct AccountId20: Equatable {
        let network: NetworkId
        let accountId: AccountId
    }

    enum Junction: Equatable {
        case parachain(_ paraId: ParaId)
        case accountId32(AccountId32)
        case accountKey20(AccountId20)
        case palletInstance(_ index: UInt8)
        case generalIndex(_ index: BigUInt)
        case generalKey(_ key: Data)
        case other(XcmUni.RawName, XcmUni.RawValue)
    }

    struct Junctions: Equatable {
        let items: [Junction]

        init(items: [Junction]) {
            self.items = items
        }
    }
}

extension XcmUni.Junctions {
    func appending(components: [XcmUni.Junction]) -> XcmUni.Junctions {
        XcmUni.Junctions(items: items + components)
    }

    func prepending(components: [XcmUni.Junction]) -> XcmUni.Junctions {
        XcmUni.Junctions(items: components + items)
    }

    func lastComponent() -> (XcmUni.Junctions, XcmUni.Junctions) {
        guard let lastJunction = items.last else {
            return (self, XcmUni.Junctions(items: []))
        }

        let remaningItems = Array(items.dropLast())

        return (XcmUni.Junctions(items: remaningItems), XcmUni.Junctions(items: [lastJunction]))
    }
}

extension XcmUni.NetworkId: XcmUniCodable {
    init(from decoder: any Decoder, configuration _: Xcm.Version) throws {
        let singleContainer = try decoder.singleValueContainer()

        if singleContainer.decodeNil() {
            self = .any
            return
        }

        var unkeyedContainer = try decoder.unkeyedContainer()

        let type = try unkeyedContainer.decode(String.self)

        switch type {
        case "Any":
            self = .any
        default:
            let value = try unkeyedContainer.decode(XcmUni.RawValue.self)
            self = .other(type, value)
        }
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch self {
        case .any:
            try encodeAny(to: encoder, configuration: configuration)
        case let .other(rawName, rawValue):
            var unkeyedContainer = encoder.unkeyedContainer()
            try unkeyedContainer.encode(rawName)
            try unkeyedContainer.encode(rawValue)
        }
    }

    func encodeAny(to encoder: any Encoder, configuration: Xcm.Version) throws {
        switch configuration {
        case .V0, .V1, .V2:
            var container = encoder.unkeyedContainer()
            try container.encode("Any")
            try container.encode(JSON.null)
        case .V3, .V4, .V5:
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

extension XcmUni.AccountId32: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case network
        case accountId = "id"
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        network = try container.decode(XcmUni.NetworkId.self, forKey: .network, configuration: configuration)
        accountId = try container.decode(BytesCodable.self, forKey: .accountId).wrappedValue
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(network, forKey: .network, configuration: configuration)
        try container.encode(BytesCodable(wrappedValue: accountId), forKey: .accountId)
    }
}

extension XcmUni.AccountId20: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case network
        case accountId = "key"
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        network = try container.decode(XcmUni.NetworkId.self, forKey: .network, configuration: configuration)
        accountId = try container.decode(BytesCodable.self, forKey: .accountId).wrappedValue
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(network, forKey: .network, configuration: configuration)
        try container.encode(BytesCodable(wrappedValue: accountId), forKey: .accountId)
    }
}

extension XcmUni.Junction: XcmUniCodable {
    static let parachainField = "Parachain"
    static let accountId32Field = "AccountId32"
    static let accountKey20Field = "AccountKey20"
    static let palletInstanceField = "PalletInstance"
    static let generalIndexField = "GeneralIndex"
    static let generalKeyField = "GeneralKey"

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        var container = try decoder.unkeyedContainer()

        let type = try container.decode(String.self)

        switch type {
        case Self.parachainField:
            let paraId = try container.decode(StringScaleMapper<ParaId>.self).value
            self = .parachain(paraId)
        case Self.accountId32Field:
            let accountId = try container.decode(XcmUni.AccountId32.self, configuration: configuration)
            self = .accountId32(accountId)
        case Self.accountKey20Field:
            let accountKey = try container.decode(XcmUni.AccountId20.self, configuration: configuration)
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
        default:
            let value = try container.decode(XcmUni.RawValue.self)
            self = .other(type, value)
        }
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.unkeyedContainer()

        switch self {
        case let .parachain(paraId):
            try container.encode(Self.parachainField)
            try container.encode(StringScaleMapper(value: paraId))
        case let .accountId32(value):
            try container.encode(Self.accountId32Field)
            try container.encode(value, configuration: configuration)
        case let .accountKey20(value):
            try container.encode(Self.accountKey20Field)
            try container.encode(value, configuration: configuration)
        case let .palletInstance(index):
            try container.encode(Self.palletInstanceField)
            try container.encode(StringScaleMapper(value: index))
        case let .generalIndex(index):
            try container.encode(Self.generalIndexField)
            try container.encode(StringScaleMapper(value: index))
        case let .generalKey(key):
            try container.encode(Self.generalKeyField)
            try container.encode(BytesCodable(wrappedValue: key))
        case let .other(rawName, rawValue):
            try container.encode(rawName)
            try container.encode(rawValue)
        }
    }
}

extension XcmUni.Junctions: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case items
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(items, forKey: .items, configuration: configuration)
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        items = try container.decode(
            [XcmUni.Junction].self,
            forKey: .items,
            configuration: configuration
        )
    }
}
