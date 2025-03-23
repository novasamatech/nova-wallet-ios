import Foundation
import SubstrateSdk
import BigInt

extension XcmV3 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV3.Junctions
    }
}

extension XcmV3.Multilocation {
    static func location(
        for targetChain: ChainModel,
        parachainId: ParaId?,
        relativeTo origin: ChainModel
    ) -> XcmV3.Multilocation {
        let parents: UInt8 = if !origin.isRelaychain, origin.chainId != targetChain.chainId {
            1
        } else {
            0
        }

        let junctions: XcmV3.Junctions

        if let parachainId {
            let networkJunction = XcmV3.Junction.parachain(parachainId)
            junctions = XcmV3.Junctions(items: [networkJunction])
        } else {
            junctions = XcmV3.Junctions(items: [])
        }

        return XcmV3.Multilocation(parents: parents, interior: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        in chain: ChainModel
    ) -> XcmV3.Multilocation {
        let accountIdJunction: XcmV3.Junction

        if chain.isEthereumBased {
            let accountIdValue = XcmV3.AccountId20Value(network: nil, key: accountId)
            accountIdJunction = XcmV3.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV3.AccountId32Value(network: nil, accountId: accountId)
            accountIdJunction = XcmV3.Junction.accountId32(accountIdValue)
        }

        return XcmV3.Multilocation(
            parents: parents,
            interior: XcmV3.Junctions(
                items: interior.items + [accountIdJunction]
            )
        )
    }
}
