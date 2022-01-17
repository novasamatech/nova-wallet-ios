import Foundation

struct PolkadotExtensionExtrinsic: Codable {
    /**
     *   The ss-58 encoded address
     */
    let address: String

    /**
     *   The checkpoint hash of the block, in hex
     */
    let blockHash: String

    /**
     *   The checkpoint block number, in hex
     */
    let blockNumber: String

    /**
     *   The era for this transaction, in hex
     */
    let era: String

    /**
     *   The genesis hash of the chain, in hex
     */
    let genesisHash: String

    /**
     *   The encoded method (with arguments) in hex
     */
    let method: String

    /**
     *   The nonce for this transaction, in hex
     */
    let nonce: String

    /**
     *   The current spec version for the runtime
     */
    let specVersion: String

    /**
     *   The tip for this transaction, in hex
     */
    let tip: String

    /**
     *   The current transaction version for the runtime
     */
    let transactionVersion: String

    /**
     *   The applicable signed extensions for this runtime
     */
    let signedExtensions: [String]

    /**
     *   The version of the extrinsic we are dealing with
     */
    let version: UInt
}
