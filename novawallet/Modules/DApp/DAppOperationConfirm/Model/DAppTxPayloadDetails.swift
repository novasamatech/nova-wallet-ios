import Foundation
import SubstrateSdk

/**
 *  What the details sheet shows for a createTransaction request: the call and the extensions
 *  as the wallet decoded them, not the hex the dApp sent.
 */
struct DAppTxPayloadDetails: Encodable {
    struct Extension: Encodable {
        let extra: JSON?
        let additionalSigned: JSON
    }

    let signer: AccountAddress
    let method: RuntimeCall<JSON>
    let extrinsicVersion: UInt8
    let txExtVersion: UInt8
    let extensions: [String: Extension]

    /**
     *   The extensions the dApp left out and the wallet fills with its own values
     */
    let walletExtensions: [String]
}

extension DAppTxPayloadDetails {
    init(resolution: DAppTxPayloadResolution, signer: AccountAddress) {
        self.signer = signer
        method = resolution.call

        extrinsicVersion = resolution.extrinsicVersion.formatNumber
        txExtVersion = resolution.extrinsicVersion.extensionVersion

        extensions = resolution.extensions.reduce(into: [:]) { result, resolved in
            if case let .dApp(supplied) = resolved.source {
                result[resolved.identifier] = Extension(extra: supplied.explicit, additionalSigned: supplied.implicit)
            }
        }

        walletExtensions = resolution.extensions
            .map(\.identifier)
            .filter { resolution.isProvidedByWallet($0) }
    }
}
