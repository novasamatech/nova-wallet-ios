import Foundation
import SubstrateSdk
import BigInt

extension XcmV3 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV3.Junctions
    }

    typealias AbsoluteLocation = XcmV3.Junctions
}

extension XcmV3.AbsoluteLocation {
    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    static func createWithRawPath(_ path: JSON) throws -> XcmV3.AbsoluteLocation {
        var junctions: [XcmV3.Junction] = []

        if let parachainId = path.parachainId?.unsignedIntValue {
            let networkJunction = XcmV3.Junction.parachain(ParaId(parachainId))
            junctions.append(networkJunction)
        }

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)

            let model = XcmV3.GeneralKeyValue(
                length: generalKey.count,
                partialData: generalKey
            )

            junctions.append(.generalKey(model))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        return XcmV3.AbsoluteLocation(items: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> XcmV3.AbsoluteLocation {
        let accountIdJunction: XcmV3.Junction

        if isEthereumBase {
            let accountIdValue = XcmV3.AccountId20Value(network: nil, key: accountId)
            accountIdJunction = XcmV3.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV3.AccountId32Value(network: nil, accountId: accountId)
            accountIdJunction = XcmV3.Junction.accountId32(accountIdValue)
        }

        return appending(components: [accountIdJunction])
    }

    func fromPointOfView(location: XcmV3.AbsoluteLocation) -> XcmV3.Multilocation {
        let commonPrefixLength = zip(items, location.items).prefix { $0 == $1 }.count

        let parents = location.items.count - commonPrefixLength
        let items = items.suffix(items.count - commonPrefixLength)

        return XcmV3.Multilocation(
            parents: UInt8(parents),
            interior: XcmV3.Junctions(items: Array(items))
        )
    }
}
