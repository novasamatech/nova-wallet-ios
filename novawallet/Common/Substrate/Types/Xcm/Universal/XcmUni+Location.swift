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
    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    static func createWithRawPath(_ path: JSON) throws -> XcmUni.AbsoluteLocation {
        var junctions: [XcmUni.Junction] = []

        if let parachainId = path.parachainId?.unsignedIntValue {
            let networkJunction = XcmUni.Junction.parachain(ParaId(parachainId))
            junctions.append(networkJunction)
        }

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)

            let model = XcmUni.GeneralKeyValue(data: generalKey)

            junctions.append(.generalKey(model))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
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
