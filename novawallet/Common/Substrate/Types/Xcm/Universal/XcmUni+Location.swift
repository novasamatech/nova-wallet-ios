import Foundation
import SubstrateSdk
import BigInt

extension XcmUni {
    struct RelativeLocation: Equatable {
        let parents: UInt8
        let interior: XcmUni.Junctions
    }

    typealias AbsoluteLocation = XcmUni.Junctions
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
            junctions.append(.generalKey(generalKey))
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
}
