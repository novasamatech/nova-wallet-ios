import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    struct RelativeLocation: Equatable {
        let parents: UInt8
        let interior: XcmUni.Junctions

        init(parents: UInt8, interior: XcmUni.Junctions) {
            self.parents = parents
            self.interior = interior
        }

        init(parents: UInt8, items: [XcmUni.Junction]) {
            self.parents = parents
            interior = .init(items: items)
        }
    }

    typealias AbsoluteLocation = XcmUni.Junctions
}

extension XcmUni.RelativeLocation {
    func toAssetId() -> XcmUni.AssetId {
        .init(location: self)
    }
}

extension XcmUni.AbsoluteLocation {
    /// Keys of a `multiLocation` object in the dynamic XCM config (nova-utils `assetsLocation`).
    enum RawPathKey: String, CaseIterable {
        case globalConsensus
        case parachainId
        case palletInstance
        case generalKey
        case generalIndex
        case accountKey20
    }

    enum RawPathError: Error {
        case unsupportedKeys(Set<String>)
        case invalidValue(key: RawPathKey, value: JSON)
        case conflictingKeys(RawPathKey, RawPathKey)
        case unsupportedConsensus(JSON)
        case invalidAccountKey20Length(Int)
    }

    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    /// A location whose path starts with GlobalConsensus is rooted outside the local consensus system
    /// (e.g. Snowbridge assets live under GlobalConsensus(Ethereum)). Chains of the local consensus never
    /// carry this junction in their absolute location.
    var isForeignConsensus: Bool {
        if case .globalConsensus = items.first {
            return true
        }

        return false
    }

    /// Parses a `multiLocation` config object. Every present key must parse, and unknown keys are an error:
    /// a silently dropped junction would turn the asset into a different one (e.g. the chain's native token).
    static func createWithRawPath(_ path: JSON) throws -> XcmUni.AbsoluteLocation {
        let fields = try RawPathFields(path)

        let junctions = try [
            fields.globalConsensus(),
            fields.parachain(),
            fields.palletInstance(),
            fields.generalKeyOrIndex(),
            fields.accountKey20()
        ].compactMap { $0 }

        return XcmUni.AbsoluteLocation(items: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> XcmUni.AbsoluteLocation {
        let accountIdJunction: XcmUni.Junction

        if isEthereumBase {
            let accountIdValue = XcmUni.AccountId20(network: .any, accountId: accountId)
            accountIdJunction = XcmUni.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmUni.AccountId32(network: .any, accountId: accountId)
            accountIdJunction = XcmUni.Junction.accountId32(accountIdValue)
        }

        return appending(components: [accountIdJunction])
    }

    func fromPointOfView(location: XcmUni.AbsoluteLocation) -> XcmUni.RelativeLocation {
        if isForeignConsensus, !location.isForeignConsensus {
            // up to the relay (one hop per junction of the viewer) and one more hop to the universal level
            return XcmUni.RelativeLocation(parents: UInt8(location.items.count + 1), interior: self)
        }

        let commonPrefixLength = zip(items, location.items).prefix { $0 == $1 }.count

        let parents = location.items.count - commonPrefixLength
        let items = items.suffix(items.count - commonPrefixLength)

        return XcmUni.RelativeLocation(
            parents: UInt8(parents),
            interior: XcmUni.Junctions(items: Array(items))
        )
    }

    func fromChainPointOfView(_ paraId: ParaId?) -> XcmUni.RelativeLocation {
        let location = XcmUni.AbsoluteLocation(paraId: paraId)

        return fromPointOfView(location: location)
    }
}

extension XcmUni.RelativeLocation {
    var accountId: AccountId? {
        switch interior.items.last {
        case let .accountId32(account):
            return account.accountId
        case let .accountKey20(account):
            return account.accountId
        default:
            return nil
        }
    }

    func lastItemLocation() -> XcmUni.RelativeLocation {
        let (_, lastComponent) = interior.lastComponent()

        return XcmUni.RelativeLocation(parents: 0, interior: lastComponent)
    }

    func dropingLastItem() -> XcmUni.RelativeLocation {
        let (prefixed, _) = interior.lastComponent()

        return XcmUni.RelativeLocation(parents: parents, interior: prefixed)
    }
}

extension XcmUni.RelativeLocation: XcmUniCodable {
    enum CodingKeys: String, CodingKey {
        case parents
        case interior
    }

    func encode(to encoder: any Encoder, configuration: Xcm.Version) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(StringScaleMapper(value: parents), forKey: .parents)
        try container.encode(interior, forKey: .interior, configuration: configuration)
    }

    init(from decoder: any Decoder, configuration: Xcm.Version) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        parents = try container.decode(StringScaleMapper<UInt8>.self, forKey: .parents).value
        interior = try container.decode(XcmUni.Junctions.self, forKey: .interior, configuration: configuration)
    }
}

private extension XcmUni.AbsoluteLocation {
    /// Validated view over a `multiLocation` config object: one parser per supported key.
    struct RawPathFields {
        let fields: [String: JSON]

        init(_ path: JSON) throws {
            guard let fields = path.dictValue else {
                throw RawPathError.invalidValue(key: .parachainId, value: path)
            }

            let unsupportedKeys = Set(fields.keys).subtracting(RawPathKey.allCases.map(\.rawValue))

            guard unsupportedKeys.isEmpty else {
                throw RawPathError.unsupportedKeys(unsupportedKeys)
            }

            self.fields = fields
        }

        func globalConsensus() throws -> XcmUni.Junction? {
            guard let value = fields[RawPathKey.globalConsensus.rawValue] else {
                return nil
            }

            return .globalConsensus(try XcmUni.NetworkId.createWithRawPath(value))
        }

        func parachain() throws -> XcmUni.Junction? {
            guard let value = fields[RawPathKey.parachainId.rawValue] else {
                return nil
            }

            guard let rawId = value.unsignedIntValue, let paraId = ParaId(exactly: rawId) else {
                throw RawPathError.invalidValue(key: .parachainId, value: value)
            }

            return .parachain(paraId)
        }

        func palletInstance() throws -> XcmUni.Junction? {
            guard let value = fields[RawPathKey.palletInstance.rawValue] else {
                return nil
            }

            guard let rawIndex = value.unsignedIntValue, let index = UInt8(exactly: rawIndex) else {
                throw RawPathError.invalidValue(key: .palletInstance, value: value)
            }

            return .palletInstance(index)
        }

        func generalKeyOrIndex() throws -> XcmUni.Junction? {
            let keyValue = fields[RawPathKey.generalKey.rawValue]
            let indexValue = fields[RawPathKey.generalIndex.rawValue]

            if keyValue != nil, indexValue != nil {
                throw RawPathError.conflictingKeys(.generalKey, .generalIndex)
            }

            if let keyValue {
                guard let keyString = keyValue.stringValue, let generalKey = try? Data(hexString: keyString) else {
                    throw RawPathError.invalidValue(key: .generalKey, value: keyValue)
                }

                return .generalKey(XcmUni.GeneralKeyValue(data: generalKey))
            }

            if let indexValue {
                guard let indexString = indexValue.stringValue, let generalIndex = BigUInt(indexString) else {
                    throw RawPathError.invalidValue(key: .generalIndex, value: indexValue)
                }

                return .generalIndex(generalIndex)
            }

            return nil
        }

        func accountKey20() throws -> XcmUni.Junction? {
            guard let value = fields[RawPathKey.accountKey20.rawValue] else {
                return nil
            }

            guard let keyString = value.stringValue, let accountKey = try? Data(hexString: keyString) else {
                throw RawPathError.invalidValue(key: .accountKey20, value: value)
            }

            guard accountKey.count == XcmUni.AccountId20.keySize else {
                throw RawPathError.invalidAccountKey20Length(accountKey.count)
            }

            return .accountKey20(XcmUni.AccountId20(network: .any, accountId: accountKey))
        }
    }
}
