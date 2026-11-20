import Foundation
import BigInt
import SubstrateSdk

/**
 *  How a verified createTransaction payload pays for itself. The payment extension of the dApp reaches
 *  the extrinsic with the bytes it sent, so the confirmation has to show the asset and the tip it carries.
 */
struct DAppTxPayloadPayment {
    /**
     *   The asset the dApp pays the fee in or nil when it is the native token
     */
    let feeAsset: ChainAsset?
}

enum DAppTxPayloadPaymentResolver {
    enum Constants {
        static let tipField = "tip"
        static let feeAssetIdField = "assetId"
    }

    static let paymentExtensionIds = [
        Extrinsic.TransactionExtensionId.txPayment,
        Extrinsic.TransactionExtensionId.assetTxPayment
    ]

    /**
     *  Fails with `DAppCreateTransactionError.decodeError` for a payload that pays in a way the fee row
     *  can't show: in an asset the wallet has no counterpart for or with a tip that isn't
     *  in a payment extension the wallet reads.
     */
    static func resolve(
        _ resolution: DAppTxPayloadResolution,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> DAppTxPayloadPayment {
        var feeAsset: ChainAsset?

        for resolved in resolution.extensions {
            guard case let .dApp(supplied) = resolved.source else {
                continue
            }

            switch resolved.identifier {
            case Extrinsic.TransactionExtensionId.txPayment:
                _ = try readTip(of: resolved.identifier, explicit: supplied.explicit)
            case Extrinsic.TransactionExtensionId.assetTxPayment:
                _ = try readTip(of: resolved.identifier, explicit: supplied.explicit)
                feeAsset = try resolveFeeAsset(from: supplied.explicit, chain: chain, codingFactory: codingFactory)
            default:
                guard !carriesTip(supplied.explicit) else {
                    throw DAppCreateTransactionError.decodeError(
                        details: "\(resolved.identifier) carries a tip the wallet can't add to the fee"
                    )
                }
            }
        }

        return DAppTxPayloadPayment(feeAsset: feeAsset)
    }

    /**
     *  The tips of the payment extensions in the explicit parts of an extrinsic. A tip is always
     *  in the native token: the runtime adds it to the fee before converting the sum to the fee asset.
     */
    static func totalTip(in extra: ExtrinsicExtra) throws -> BigUInt {
        try paymentExtensionIds.reduce(BigUInt(0)) { total, identifier in
            guard let explicit = extra[identifier] else {
                return total
            }

            return total + (try readTip(of: identifier, explicit: explicit))
        }
    }
}

// MARK: Private

private extension DAppTxPayloadPaymentResolver {
    static func readTip(of identifier: String, explicit: JSON?) throws -> BigUInt {
        let tipValue: JSON? = switch identifier {
        case Extrinsic.TransactionExtensionId.txPayment:
            explicit
        case Extrinsic.TransactionExtensionId.assetTxPayment:
            explicit?.dictValue?[Constants.tipField]
        default:
            nil
        }

        guard let tip = tipValue.flatMap({ parseAmount($0) }) else {
            throw DAppCreateTransactionError.decodeError(details: "\(identifier) has a tip the wallet can't read")
        }

        return tip
    }

    static func resolveFeeAsset(
        from explicit: JSON?,
        chain: ChainModel,
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ChainAsset? {
        let identifier = Extrinsic.TransactionExtensionId.assetTxPayment

        guard let assetId = explicit?.dictValue?[Constants.feeAssetIdField] else {
            throw DAppCreateTransactionError.decodeError(
                details: "\(identifier) has a fee asset the wallet can't read"
            )
        }

        guard !assetId.isNull else {
            return nil
        }

        guard
            chain.hasAssetHubFees,
            let feeAsset = AssetHubTokensConverter.convertToLocalAsset(
                for: assetId,
                on: chain,
                using: codingFactory
            ) else {
            throw DAppCreateTransactionError.decodeError(
                details: "\(identifier) pays the fee in an asset the wallet doesn't know"
            )
        }

        return feeAsset
    }

    // An extension the wallet has no payment rules for may nest its fields, so the tip is looked for at any depth
    static func carriesTip(_ explicit: JSON?) -> Bool {
        switch explicit {
        case let .dictionaryValue(fields):
            fields.contains { name, value in
                name == Constants.tipField ? !isZeroAmount(value) : carriesTip(value)
            }
        case let .arrayValue(items):
            items.contains { carriesTip($0) }
        default:
            false
        }
    }

    static func isZeroAmount(_ value: JSON) -> Bool {
        value.isNull || parseAmount(value) == BigUInt(0)
    }

    static func parseAmount(_ value: JSON) -> BigUInt? {
        switch value {
        case let .stringValue(amount):
            BigUInt(amount)
        case let .unsignedIntValue(amount):
            BigUInt(amount)
        default:
            nil
        }
    }
}
