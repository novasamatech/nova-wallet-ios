import Foundation
import SubstrateSdk

struct XcmTransfers: Decodable {
    let assetsLocation: [String: JSON]
    let instructions: [String: [String]]
    let chains: [XcmChain]

    func assetLocation(for key: String) -> JSON? {
        assetsLocation[key]
    }

    func instructions(for key: String) -> [String]? {
        instructions[key]
    }
}
