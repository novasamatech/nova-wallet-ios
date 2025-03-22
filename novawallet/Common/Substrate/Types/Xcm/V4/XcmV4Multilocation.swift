import Foundation
import SubstrateSdk

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
}
