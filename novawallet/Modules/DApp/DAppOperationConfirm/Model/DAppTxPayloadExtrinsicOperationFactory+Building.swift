import Foundation
import SubstrateSdk

extension DAppTxPayloadExtrinsicOperationFactory {
    func buildExtrinsic(
        verification: Verification,
        sender: Sender,
        walletValues: WalletValues,
        codingFactory: RuntimeCoderFactoryProtocol,
        signingClosure: @escaping (Data, ExtrinsicSigningContext) throws -> Data
    ) throws -> Data {
        let account = sender.resolution.account

        var builder = try addingSigner(
            account.accountId,
            to: sender.builder.with(signaturePayloadFormat: account.type.signaturePayloadFormat),
            extrinsicVersion: verification.resolution.extrinsicVersion
        )

        builder = addingWalletExtensions(to: builder, verification: verification, walletValues: walletValues)

        for resolved in verification.resolution.extensions {
            guard
                case let .dApp(supplied) = resolved.source,
                !sender.walletOverriddenIds.contains(resolved.identifier) else {
                continue
            }

            builder = builder.adding(
                transactionExtension: RawTransactionExtension(
                    txExtensionId: resolved.identifier,
                    rawImplicit: supplied.rawImplicit,
                    decodedExplicit: supplied.explicit,
                    coder: supplied.coder
                )
            )
        }

        let context = ExtrinsicSigningContext.Substrate(
            senderResolution: sender.resolution,
            extrinsicMemo: builder.makeMemo(),
            codingFactory: codingFactory
        )

        return try builder
            .signing(with: signingClosure, context: context, codingFactory: codingFactory)
            .build(using: codingFactory, metadata: codingFactory.metadata)
    }

    /**
     *  A legacy extrinsic names the signer with the address type of the runtime while VerifyMultiSignature
     *  of a general transaction, which gets the same value from the builder, takes the bare account id.
     */
    func addingSigner(
        _ accountId: AccountId,
        to builder: ExtrinsicBuilderProtocol,
        extrinsicVersion: Extrinsic.Version
    ) throws -> ExtrinsicBuilderProtocol {
        switch extrinsicVersion {
        case .V4:
            try builder.with(address: MultiAddress.accoundId(accountId))
        case .V5:
            try builder.with(address: BytesCodable(wrappedValue: accountId))
        }
    }

    /**
     *  The builder starts with the wallet's genesis, runtime versions, zero tip and a disabled metadata
     *  hash; here it gets the values that are known only now. Whatever the dApp supplied replaces them later.
     */
    func addingWalletExtensions(
        to initialBuilder: ExtrinsicBuilderProtocol,
        verification: Verification,
        walletValues: WalletValues
    ) -> ExtrinsicBuilderProtocol {
        var builder = initialBuilder

        if let metadataHash = verification.metadataHash {
            builder = builder.with(metadataHash: metadataHash)
        }

        if let mortality = walletValues.mortality {
            builder = builder.with(era: mortality.era, blockHash: mortality.blockHash)
        }

        if let nonce = walletValues.nonce {
            builder = builder.with(nonce: nonce)
        }

        for walletExtension in signedExtensionFactory.createExtensions()
            where verification.resolution.isProvidedByWallet(walletExtension.txExtensionId) {
            builder = builder.adding(transactionExtension: walletExtension)
        }

        return builder
    }

    func findFeeAsset(
        in resolution: DAppTxPayloadResolution,
        codingFactory: RuntimeCoderFactoryProtocol
    ) -> ChainAsset? {
        guard
            chain.hasAssetHubFees,
            let payment = resolution.supplied(for: Extrinsic.TransactionExtensionId.assetTxPayment),
            let assetId = payment.explicit?.dictValue?[Constants.feeAssetIdField] else {
            return nil
        }

        return AssetHubTokensConverter.convertToLocalAsset(for: assetId, on: chain, using: codingFactory)
    }
}
