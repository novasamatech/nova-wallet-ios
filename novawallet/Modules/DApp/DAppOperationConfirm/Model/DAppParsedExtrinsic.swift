import Foundation
import BigInt
import SubstrateSdk

struct DAppParsedExtrinsic: Codable {
    let address: String
    let blockHash: String
    let blockNumber: BigUInt
    let era: Era
    let genesisHash: String
    let method: RuntimeCall<JSON>
    let nonce: BigUInt
    let specVersion: UInt32
    let tip: BigUInt
    let transactionVersion: UInt32
    let signedExtensions: [String]
    let version: UInt
}
