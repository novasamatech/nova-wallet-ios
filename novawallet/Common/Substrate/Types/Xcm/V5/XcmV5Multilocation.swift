import Foundation
import SubstrateSdk
import BigInt

extension XcmV5 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV5.Junctions
    }

    typealias AbsoluteLocation = XcmV5.Junctions
}

extension XcmV5.AbsoluteLocation {
    init(paraId: ParaId?) {
        if let paraId {
            items = [.parachain(paraId)]
        } else {
            items = []
        }
    }

    static func createWithRawPath(_ path: JSON) throws -> XcmV5.AbsoluteLocation {
        var junctions: [XcmV5.Junction] = []

        if let parachainId = path.parachainId?.unsignedIntValue {
            let networkJunction = XcmV5.Junction.parachain(ParaId(parachainId))
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

        return XcmV5.AbsoluteLocation(items: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        isEthereumBase: Bool
    ) -> XcmV5.AbsoluteLocation {
        let accountIdJunction: XcmV5.Junction

        if isEthereumBase {
            let accountIdValue = XcmV5.AccountId20Value(network: nil, key: accountId)
            accountIdJunction = XcmV5.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV5.AccountId32Value(network: nil, accountId: accountId)
            accountIdJunction = XcmV5.Junction.accountId32(accountIdValue)
        }

        return appending(components: [accountIdJunction])
    }

    func fromPointOfView(location: XcmV5.AbsoluteLocation) -> XcmV5.Multilocation {
        let commonPrefixLength = zip(items, location.items).prefix { $0 == $1 }.count

        let parents = location.items.count - commonPrefixLength
        let items = items.suffix(items.count - commonPrefixLength)

        return XcmV5.Multilocation(
            parents: UInt8(parents),
            interior: XcmV5.Junctions(items: Array(items))
        )
    }
}

extension XcmV5.Multilocation {
    var accountId: AccountId? {
        switch interior.items.last {
        case let .accountId32(account):
            return account.accountId
        case let .accountKey20(account):
            return account.key
        default:
            return nil
        }
    }
}
