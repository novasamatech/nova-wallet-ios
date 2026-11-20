import Foundation
import SubstrateSdk

/**
 *  What the wallet itself knows about the chain. A createTransaction payload is checked against these
 *  values, the ones a dApp sends are never taken on trust.
 */
struct DAppTxPayloadChainFacts {
    let genesisHash: Data
    let specVersion: UInt32
    let transactionVersion: UInt32

    /**
     *   The metadata hash computed by the wallet or nil when the chain or the runtime doesn't support it
     */
    let metadataHash: Data?
}

/**
 *  A createTransaction payload verified against the wallet's runtime: the extrinsic version to build
 *  and where each transaction extension of its pipeline takes the value from.
 */
struct DAppTxPayloadResolution {
    struct SuppliedExtension {
        let rawExplicit: Data
        let rawImplicit: Data

        /**
         *   The explicit part decoded by the coder that puts it back both to the signed payload and to the extrinsic
         */
        let explicit: JSON?
        let implicit: JSON
        let coder: TransactionExtensionCoding
    }

    enum Source {
        /// The bytes sent by the dApp, decoded and re-encoded by the wallet without a difference
        case dApp(SuppliedExtension)

        /// The dApp omitted the extension and the wallet knows how to fill it
        case wallet

        /// The extension that carries the signature: always produced by the wallet
        case signature

        /// The dApp omitted the extension and the runtime accepts it empty
        case runtimeDefault
    }

    struct Extension {
        let identifier: String
        let source: Source
    }

    let extrinsicVersion: Extrinsic.Version
    let call: RuntimeCall<JSON>

    /**
     *   The extensions of the pipeline of the chosen version in the order the runtime declares them
     */
    let extensions: [Extension]
}

extension DAppTxPayloadResolution {
    func supplied(for identifier: String) -> SuppliedExtension? {
        guard
            let source = extensions.first(where: { $0.identifier == identifier })?.source,
            case let .dApp(supplied) = source else {
            return nil
        }

        return supplied
    }

    func isProvidedByWallet(_ identifier: String) -> Bool {
        guard let source = extensions.first(where: { $0.identifier == identifier })?.source else {
            return false
        }

        switch source {
        case .wallet:
            return true
        case .dApp, .signature, .runtimeDefault:
            return false
        }
    }
}

/**
 *  The numbers a runtime and a dApp name the extrinsic formats and extension sets with.
 */
extension Extrinsic.Version {
    static let legacyFormatNumber: UInt8 = 4
    static let generalFormatNumber: UInt8 = 5

    // legacy extrinsics have no version of the extension set and use the base one
    static let baseExtensionVersion: UInt8 = 0

    var formatNumber: UInt8 {
        switch self {
        case .V4:
            Self.legacyFormatNumber
        case .V5:
            Self.generalFormatNumber
        }
    }

    var extensionVersion: UInt8 {
        switch self {
        case .V4:
            Self.baseExtensionVersion
        case let .V5(extensionVersion):
            extensionVersion
        }
    }
}
