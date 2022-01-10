import Foundation
import SubstrateSdk

// Only fields that are used are stored
struct PolkadotExtensionMetadata: Decodable {
    let genesisHash: String
    let specVersion: UInt32
}
