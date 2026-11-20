import Foundation
import SubstrateSdk

extension DAppTxPayloadExtensionResolver {
    /**
     *  The coders `ExtrinsicExtraNode` applies before the ones of the registry. The node keeps the list
     *  internal (`ExtrinsicExtraNode.defaultExtensions` in Runtime/Nodes/Items/ExtrinsicExtraNode.swift
     *  of substrate-sdk-ios), so it is repeated here and must follow the SDK when the dependency is bumped:
     *  a difference makes `ensureExtrinsicKeepsSuppliedBytes` refuse valid payloads.
     */
    func createSdkCoders() -> [TransactionExtensionCoding] {
        [
            TransactionExtension.CheckMortality.getTransactionExtensionCoder(),
            TransactionExtension.CheckNonce.getTransactionExtensionCoder(),
            TransactionExtension.ChargeTransactionPayment.getTransactionExtensionCoder(),
            CheckMetadataHashCoder()
        ]
    }

    func dedicatedCoder(for identifier: String, runtime: Runtime) -> TransactionExtensionCoding? {
        (createSdkCoders() + runtime.extraNode.customExtensions).last { $0.txExtensionId == identifier }
    }

    // The same choice ExtrinsicExtraNode makes when it writes the extensions to the extrinsic
    func explicitCoder(for identifier: String, runtime: Runtime) -> TransactionExtensionCoding {
        dedicatedCoder(for: identifier, runtime: runtime) ?? DefaultVersionedTransactionExtensionCoder(
            txExtensionId: identifier,
            metadata: runtime.metadata
        )
    }

    /**
     *  The signed payload takes the explicit parts from the coders chosen here while the extrinsic itself
     *  is written by the runtime's extra node. Asking the node directly proves both give the dApp's bytes.
     */
    func ensureExtrinsicKeepsSuppliedBytes(
        of extensions: [DAppTxPayloadResolution.Extension],
        pipeline: [SignedExtensionV14],
        runtime: Runtime
    ) throws {
        var extra = ExtrinsicExtra()
        var expected = Data()

        for (descriptor, resolved) in zip(pipeline, extensions) {
            if case let .dApp(supplied) = resolved.source {
                extra[descriptor.identifier] = supplied.explicit
                expected.append(supplied.rawExplicit)
            } else if
                dedicatedCoder(for: descriptor.identifier, runtime: runtime) == nil,
                runtime.codingFactory.createEncoder().canEncodeOptional(for: String(descriptor.type)) {
                // the node writes None for an optional extension it has no value for
                expected.append(Constants.encodedNone)
            }
        }

        let encoded = try decoding(Field.extensions) {
            let encoder = runtime.codingFactory.createEncoder()
            try runtime.extraNode.encode(extra, extensionVersion: runtime.extensionVersion, encoder: encoder)

            return try encoder.encode()
        }

        guard encoded == expected else {
            throw DAppCreateTransactionError.decodeError(
                details: "the extensions can't be written to the extrinsic unchanged"
            )
        }
    }

    func decodeHex(_ hex: String, field: String) throws -> Data {
        do {
            return try Data(hexString: hex)
        } catch {
            throw DAppCreateTransactionError.invalidHex(details: field)
        }
    }

    func ensureCanonical(_ subject: String, remained: Int, original: Data, encoded: Data) throws {
        guard remained == 0 else {
            throw DAppCreateTransactionError.decodeError(details: "\(subject) has \(remained) trailing bytes")
        }

        guard encoded == original else {
            throw DAppCreateTransactionError.decodeError(details: "\(subject) is not a canonical encoding")
        }
    }

    func decoding<T>(_ subject: String, closure: () throws -> T) throws -> T {
        do {
            return try closure()
        } catch let error as DAppCreateTransactionError {
            throw error
        } catch {
            throw DAppCreateTransactionError.decodeError(
                details: "\(subject) can't be decoded with the wallet's runtime"
            )
        }
    }
}
