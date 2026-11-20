import Foundation

/**
 *  TxPayloadV1 of the createTransaction signer method (RFC polkadot-js/api#6213).
 *  The bridge drops context.metadata before sending: the wallet relies on its own runtime metadata.
 */
struct PolkadotExtensionTxPayload: Decodable {
    static let supportedVersion: UInt = 1

    struct Extension: Decodable {
        /**
         *   The identifier of the transaction extension as it appears in the runtime metadata
         */
        let id: String

        /**
         *   The SCALE encoded explicit part of the extension that goes to the extrinsic, in hex
         */
        let extra: String

        /**
         *   The SCALE encoded implicit part of the extension that is only signed, in hex
         */
        let additionalSigned: String
    }

    struct Token: Decodable {
        let symbol: String
        let decimals: UInt16
    }

    struct Context: Decodable {
        let token: Token?
        let bestBlockHeight: BlockNumber

        /**
         *   The hash of the best block known to the dApp, in hex
         */
        let bestBlockHash: String

        /**
         *   The genesis hash of the chain, in hex
         */
        let genesisHash: String
    }

    let version: UInt

    /**
     *   The address of the account expected to sign or nil to let the wallet choose
     */
    let signer: String?

    /**
     *   The SCALE encoded call, in hex
     */
    let callData: String

    let extensions: [Extension]

    /**
     *   The version of the transaction extensions set: 0 or nil stands for a v4 signed extrinsic
     */
    let txExtVersion: UInt?

    let context: Context
}
