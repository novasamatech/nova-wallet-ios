import Foundation

struct PolkadotExtensionMetadataResponse: Encodable {
    let genesisHash: String
    let specVersion: UInt32
}
