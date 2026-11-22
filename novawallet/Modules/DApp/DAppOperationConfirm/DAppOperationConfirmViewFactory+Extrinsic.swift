import Foundation
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

extension DAppOperationConfirmViewFactory {
    static func createCreateTransactionInteractor(
        for request: DAppOperationRequest,
        chain: ChainModel
    ) -> DAppCreateTransactionConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let payload = try? request.operationData.map(to: PolkadotExtensionTxPayload.self),
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared,
            let account = request.wallet.fetchByAccountId(request.accountId, request: chain.accountRequest())
        else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicFactory = createTxPayloadExtrinsicFactory(
            for: payload,
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let feeEstimatorHost = createFeeEstimatorHost(
            for: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        let feeOperationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            feeEstimationRegistry: createTxPayloadFeeEstimationRegistry(host: feeEstimatorHost),
            operationManager: OperationManager(operationQueue: operationQueue),
            usesStateCallForFee: chain.feeViaRuntimeCall
        )

        return DAppCreateTransactionConfirmInteractor(
            request: request,
            chain: chain,
            account: account,
            extrinsicFactory: extrinsicFactory,
            feeOperationFactory: feeOperationFactory,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            priceProviderFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    static func createTxPayloadExtrinsicFactory(
        for payload: PolkadotExtensionTxPayload,
        account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> DAppTxPayloadExtrinsicOperationFactory {
        DAppTxPayloadExtrinsicOperationFactory(
            payload: payload,
            chain: chain,
            runtimeProvider: runtimeProvider,
            connection: connection,
            resolver: DAppTxPayloadExtensionResolver(),
            metadataHashOperationFactory: createMetadataHashFactory(),
            senderResolvingFactory: ExtrinsicSenderResolutionFactory(
                chainAccount: account,
                chain: chain,
                userStorageFacade: UserDataStorageFacade.shared
            ),
            nonceOperationFactory: TransactionNonceOperationFactory(),
            eraOperationFactory: MortalEraOperationFactory(chain: chain),
            blockHashOperationFactory: BlockHashOperationFactory(),
            signedExtensionFactory: ExtrinsicSignedExtensionFacade().createFactory(for: chain.chainId),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    static func createFeeEstimationRegistry(
        for account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> ExtrinsicFeeEstimationRegistring {
        let host = createFeeEstimatorHost(
            for: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider
        )

        return createFeeEstimationRegistry(host: host, nativeFeeEstimator: nil)
    }

    /**
     *  A createTransaction request brings the payment extension of the dApp, so its fee
     *  is the estimate of the node together with the tip that extension carries.
     */
    static func createTxPayloadFeeEstimationRegistry(
        host: ExtrinsicFeeEstimatorHostProtocol
    ) -> ExtrinsicFeeEstimationRegistring {
        createFeeEstimationRegistry(host: host, nativeFeeEstimator: createTxPayloadNativeFeeEstimator(host: host))
    }

    static func createTxPayloadNativeFeeEstimator(host: ExtrinsicFeeEstimatorHostProtocol) -> ExtrinsicFeeEstimating {
        DAppTxPayloadFeeEstimator(
            nativeFeeEstimator: ExtrinsicNativeFeeEstimator(chain: host.chain, operationQueue: host.operationQueue)
        )
    }

    static func createFeeEstimatorHost(
        for account: ChainAccountResponse,
        chain: ChainModel,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol
    ) -> ExtrinsicFeeEstimatorHostProtocol {
        ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    static func createFeeEstimationRegistry(
        host: ExtrinsicFeeEstimatorHostProtocol,
        nativeFeeEstimator: ExtrinsicFeeEstimating?
    ) -> ExtrinsicFeeEstimationRegistring {
        ExtrinsicFeeEstimationRegistry(
            chain: host.chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: host,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(
                    host: host,
                    nativeFeeEstimator: nativeFeeEstimator
                ),
                nativeFeeEstimator: nativeFeeEstimator
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: host)
        )
    }

    static func createMetadataHashFactory() -> MetadataHashOperationFactoryProtocol {
        MetadataHashOperationFactory(
            sourceProvider: MetadataHashSourceProvider.createDefault(
                storageFacade: SubstrateDataStorageFacade.shared,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
