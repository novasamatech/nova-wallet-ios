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

        let feeOperationFactory = ExtrinsicProxyOperationFactory(
            proxy: extrinsicFactory,
            runtimeRegistry: runtimeProvider,
            engine: connection,
            feeEstimationRegistry: createFeeEstimationRegistry(
                for: account,
                chain: chain,
                connection: connection,
                runtimeProvider: runtimeProvider
            ),
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
        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )
    }

    static func createMetadataHashFactory() -> MetadataHashOperationFactoryProtocol {
        MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(
                storageFacade: SubstrateDataStorageFacade.shared
            ),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
