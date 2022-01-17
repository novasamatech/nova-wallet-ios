import Foundation
import BigInt
import SubstrateSdk

struct DAppParsedExtrinsic: Encodable {
    let address: String
    let blockHash: String
    let blockNumber: BigUInt
    let era: Era
    let genesisHash: String
    let method: DAppParsedCall
    let nonce: BigUInt
    let specVersion: UInt32
    let tip: BigUInt
    let transactionVersion: UInt32
    let signedExtensions: [String]
    let version: UInt
}
