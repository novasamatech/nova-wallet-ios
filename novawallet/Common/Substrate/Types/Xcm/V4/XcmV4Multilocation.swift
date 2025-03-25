import Foundation
import SubstrateSdk
import BigInt

extension XcmV4 {
    struct Multilocation: Equatable, Codable {
        @StringCodable var parents: UInt8
        let interior: XcmV4.Junctions
    }
}

extension XcmV4.Multilocation {
    static func location(
        for targetChain: ChainModel,
        parachainId: ParaId?,
        relativeTo origin: ChainModel
    ) -> XcmV4.Multilocation {
        let parents: UInt8 = if !origin.isRelaychain, origin.chainId != targetChain.chainId {
            1
        } else {
            0
        }

        let junctions: XcmV4.Junctions

        if let parachainId {
            let networkJunction = XcmV4.Junction.parachain(parachainId)
            junctions = XcmV4.Junctions(items: [networkJunction])
        } else {
            junctions = XcmV4.Junctions(items: [])
        }

        return XcmV4.Multilocation(parents: parents, interior: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        in chain: ChainModel
    ) -> XcmV4.Multilocation {
        let accountIdJunction: XcmV4.Junction

        if chain.isEthereumBased {
            let accountIdValue = XcmV4.AccountId20Value(network: nil, key: accountId)
            accountIdJunction = XcmV4.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = XcmV4.AccountId32Value(network: nil, accountId: accountId)
            accountIdJunction = XcmV4.Junction.accountId32(accountIdValue)
        }

        return XcmV4.Multilocation(
            parents: parents,
            interior: interior.appending(components: [accountIdJunction])
        )
    }
}
