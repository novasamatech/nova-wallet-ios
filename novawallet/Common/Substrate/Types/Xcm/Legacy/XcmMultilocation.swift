import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct Multilocation: Codable, Equatable {
        @StringCodable var parents: UInt8
        let interior: Xcm.JunctionsV2
    }

    typealias AbsoluteLocation = Xcm.JunctionsV2
}

extension Xcm.AbsoluteLocation {
    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    static func createWithRawPath(_ path: JSON) throws -> Xcm.AbsoluteLocation {
        var junctions: [Xcm.Junction] = []

        if let parachainId = path.parachainId?.unsignedIntValue {
            let networkJunction = Xcm.Junction.parachain(ParaId(parachainId))
            junctions.append(networkJunction)
        }

        if let palletInstance = path.palletInstance?.unsignedIntValue {
            junctions.append(.palletInstance(UInt8(palletInstance)))
        }

        if let generalKeyString = path.generalKey?.stringValue {
            let generalKey = try Data(hexString: generalKeyString)
            junctions.append(.generalKey(generalKey))
        } else if let generalIndexString = path.generalIndex?.stringValue {
            guard let generalIndex = BigUInt(generalIndexString) else {
                throw CommonError.dataCorruption
            }

            junctions.append(.generalIndex(generalIndex))
        }

        return Xcm.AbsoluteLocation(items: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> Xcm.AbsoluteLocation {
        let accountIdJunction: Xcm.Junction

        if isEthereumBase {
            let accountIdValue = Xcm.AccountId20Value(network: .any, key: accountId)
            accountIdJunction = Xcm.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = Xcm.AccountId32Value(network: .any, accountId: accountId)
            accountIdJunction = Xcm.Junction.accountId32(accountIdValue)
        }

        return appending(components: [accountIdJunction])
    }

    func fromPointOfView(location: Xcm.AbsoluteLocation) -> Xcm.Multilocation {
        let commonPrefixLength = zip(items, location.items).prefix { $0 == $1 }.count

        let parents = location.items.count - commonPrefixLength
        let items = items.suffix(items.count - commonPrefixLength)

        return Xcm.Multilocation(
            parents: UInt8(parents),
            interior: Xcm.JunctionsV2(items: Array(items))
        )
    }
}
