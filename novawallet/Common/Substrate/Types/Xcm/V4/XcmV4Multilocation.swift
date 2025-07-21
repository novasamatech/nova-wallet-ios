import Foundation
import SubstrateSdk
import BigInt

extension XcmV4 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV4.Junctions
    }

    typealias AbsoluteLocation = XcmV4.Junctions
}

extension XcmV4.AbsoluteLocation {
    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    static func createWithRawPath(_ path: JSON) throws -> XcmV4.AbsoluteLocation {
        var junctions: [XcmV4.Junction] = []

        if let parachainId = path.parachainId?.unsignedIntValue {
            let networkJunction = XcmV4.Junction.parachain(ParaId(parachainId))
            junctions.append(networkJunction)
        }

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)
            let model = XcmV3.GeneralKeyValue(
                length: generalKey.count,
                data: H256(partialData: generalKey)
            )
            junctions.append(.generalKey(model))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        return XcmV4.AbsoluteLocation(items: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> XcmV4.AbsoluteLocation {
        let accountIdJunction: XcmV4.Junction

        if isEthereumBase {
            let accountIdValue = XcmV4.AccountId20Value(network: nil, key: accountId)
            accountIdJunction = XcmV4.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV4.AccountId32Value(network: nil, accountId: accountId)
            accountIdJunction = XcmV4.Junction.accountId32(accountIdValue)
        }

        return appending(components: [accountIdJunction])
    }

    func fromPointOfView(location: XcmV4.AbsoluteLocation) -> XcmV4.Multilocation {
        let commonPrefixLength = zip(items, location.items).prefix { $0 == $1 }.count

        let parents = location.items.count - commonPrefixLength
        let items = items.suffix(items.count - commonPrefixLength)

        return XcmV4.Multilocation(
            parents: UInt8(parents),
            interior: XcmV4.Junctions(items: Array(items))
        )
    }
}
