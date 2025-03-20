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
}
