import Foundation

struct XcmTransfers: Decodable {
    let assetsLocation: XcmAssetsLocation
    let instructions: XcmInstructions
    let chains: [XcmChain]
}
