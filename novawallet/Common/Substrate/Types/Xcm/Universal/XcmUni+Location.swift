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
    enum RawPathKey: String, CaseIterable {
        case globalConsensus
        case parachainId
        case palletInstance
        case generalKey
        case generalIndex
        case accountKey20
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

    static func createWithRawPath(_ path: JSON) throws -> XcmUni.AbsoluteLocation {
        guard let fields = path.dictValue else {
            throw CommonError.dataCorruption
        }

        let supportedKeys = Set(RawPathKey.allCases.map(\.rawValue))

        guard supportedKeys.isSuperset(of: fields.keys) else {
            throw CommonError.dataCorruption
        }

        var junctions: [XcmUni.Junction] = []

        if let globalConsensus = fields[RawPathKey.globalConsensus.rawValue] {
            junctions.append(.globalConsensus(try XcmUni.NetworkId.createWithRawPath(globalConsensus)))
        }

        if let parachainId = fields[RawPathKey.parachainId.rawValue]?.unsignedIntValue {
            junctions.append(.parachain(ParaId(parachainId)))
        }

        if let palletInstance = fields[RawPathKey.palletInstance.rawValue]?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = fields[RawPathKey.generalKey.rawValue]?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)

            junctions.append(.generalKey(XcmUni.GeneralKeyValue(data: generalKey)))
        } else if let generalIndexString = fields[RawPathKey.generalIndex.rawValue]?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        if let accountKeyString = fields[RawPathKey.accountKey20.rawValue]?.stringValue {
            let accountKey = try Data(hexString: accountKeyString)

            guard accountKey.count == 20 else {
                throw CommonError.dataCorruption
            }

            junctions.append(.accountKey20(XcmUni.AccountId20(network: .any, accountId: accountKey)))
        }

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

extension XcmUni.NetworkId {
    /// Config shape: {"ethereum": {"chainId": 1}}. Only Ethereum is supported.
    static func createWithRawPath(_ path: JSON) throws -> XcmUni.NetworkId {
        guard
            let fields = path.dictValue,
            fields.count == 1,
            let ethereum = fields["ethereum"]?.dictValue else {
            throw CommonError.dataCorruption
        }

        if let chainId = ethereum["chainId"]?.unsignedIntValue {
            return .ethereum(chainId: chainId)
        }

        if let chainIdString = ethereum["chainId"]?.stringValue, let chainId = UInt64(chainIdString) {
            return .ethereum(chainId: chainId)
        }

        throw CommonError.dataCorruption
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
