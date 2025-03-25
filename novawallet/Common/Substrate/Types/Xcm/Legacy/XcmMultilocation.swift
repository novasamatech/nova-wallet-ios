import Foundation
import SubstrateSdk
import BigInt

extension Xcm {
    struct Multilocation: Codable, Equatable {
        @StringCodable var parents: UInt8
        let interior: Xcm.JunctionsV2
    }
}

extension Xcm.Multilocation {
    static func location(
        for targetChain: ChainModel,
        parachainId: ParaId?,
        relativeTo origin: ChainModel
    ) -> Xcm.Multilocation {
        let parents: UInt8 = if !origin.isRelaychain, origin.chainId != targetChain.chainId {
            1
        } else {
            0
        }

        let junctions: Xcm.JunctionsV2

        if let parachainId {
            let networkJunction = Xcm.Junction.parachain(parachainId)
            junctions = Xcm.JunctionsV2(items: [networkJunction])
        } else {
            junctions = Xcm.JunctionsV2(items: [])
        }

        return Xcm.Multilocation(parents: parents, interior: junctions)
    }

    func appendingAccountId(
        _ accountId: AccountId,
        in chain: ChainModel
    ) -> Xcm.Multilocation {
        let accountIdJunction: Xcm.Junction

        if chain.isEthereumBased {
            let accountIdValue = Xcm.AccountId20Value(network: .any, key: accountId)
            accountIdJunction = Xcm.Junction.accountKey20(accountIdValue)
        } else {
            let accountIdValue = Xcm.AccountId32Value(network: .any, accountId: accountId)
            accountIdJunction = Xcm.Junction.accountId32(accountIdValue)
        }

        return Xcm.Multilocation(
            parents: parents,
            interior: Xcm.JunctionsV2(
                items: interior.items + [accountIdJunction]
            )
        )
    }
}
