import Foundation
import Keystore_iOS
import Foundation_iOS
import SubstrateSdk
import BigInt

struct DAppOperationConfirmViewFactory {
    static func createView(
        for request: DAppOperationRequest,
        type: DAppSigningType,
        delegate: DAppOperationConfirmDelegate
    ) -> DAppOperationConfirmViewProtocol? {
        let signAnalyticsContext = DAppSignAnalyticsContext(request: request, type: type)

        switch type {
        case let .extrinsic(chain):
            return createGenericView(
                for: createExtrinsicInteractor(for: request, chain: chain),
                chain: .left(chain),
                delegate: delegate,
                signAnalyticsContext: signAnalyticsContext,
                showsNetwork: true
            )
        case let .bytes(chain):
            return createGenericView(
                for: createSignBytesInteractor(for: request, chain: chain),
                chain: .left(chain),
                delegate: delegate,
                signAnalyticsContext: signAnalyticsContext,
                showsNetwork: false
            )
        case let .ethereumSendTransaction(chain):
            return createEvmTransactionView(
                for: chain,
                request: request,
                delegate: delegate,
                signAnalyticsContext: signAnalyticsContext,
                shouldSendTransaction: true
            )
        case let .ethereumSignTransaction(chain):
            return createEvmTransactionView(
                for: chain,
                request: request,
                delegate: delegate,
                signAnalyticsContext: signAnalyticsContext,
                shouldSendTransaction: false
            )
        case let .ethereumBytes(chain):
            return createGenericView(
                for: createEthereumPersonalSignInteractor(for: request),
                chain: chain,
                delegate: delegate,
                signAnalyticsContext: signAnalyticsContext,
                showsNetwork: false
            )
        }
    }
}

private extension DAppOperationConfirmViewFactory {
    static func createEvmTransactionView(
        for chain: DAppEitherChain,
        request: DAppOperationRequest,
        delegate: DAppOperationConfirmDelegate,
        signAnalyticsContext: DAppSignAnalyticsContext?,
        shouldSendTransaction: Bool
    ) -> DAppOperationConfirmViewProtocol? {
        guard
            let assetInfo = chain.utilityAssetBalanceInfo,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = DAppOperationEvmConfirmWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let utilityBalanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let balanceViewModelFacade = BalanceViewModelFactoryFacade(
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let validationProviderFactory = EvmValidationProviderFactory(
            presentable: wireframe,
            balanceViewModelFactory: utilityBalanceViewModelFactory,
            assetInfo: assetInfo
        )

        guard
            let interactor = createEthereumInteractor(
                for: request,
                chain: chain,
                validationProviderFactory: validationProviderFactory,
                shouldSendTransaction: shouldSendTransaction
            ) else {
            return nil
        }

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: DAppOperationGenericConfirmViewModelFactory(chain: chain),
            balanceViewModelFacade: balanceViewModelFacade,
            chain: chain,
            signAnalyticsContext: signAnalyticsContext,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DAppOperationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createGenericView(
        for interactor: (DAppOperationBaseInteractor & DAppOperationConfirmInteractorInputProtocol)?,
        chain: DAppEitherChain,
        delegate: DAppOperationConfirmDelegate,
        signAnalyticsContext: DAppSignAnalyticsContext?,
        showsNetwork: Bool
    ) -> DAppOperationConfirmViewProtocol? {
        guard
            let interactor = interactor,
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = DAppOperationConfirmWireframe()
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFacade = BalanceViewModelFactoryFacade(priceAssetInfoFactory: priceAssetInfoFactory)

        let viewModelFactory = if showsNetwork {
            DAppOperationGenericConfirmViewModelFactory(chain: chain)
        } else {
            DAppOperationBytesConfirmViewModelFactory(chain: chain)
        }

        let presenter = DAppOperationConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            delegate: delegate,
            viewModelFactory: viewModelFactory,
            balanceViewModelFacade: balanceViewModelFacade,
            chain: chain,
            signAnalyticsContext: signAnalyticsContext,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = DAppOperationConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    static func createExtrinsicInteractor(
        for request: DAppOperationRequest,
        chain: ChainModel
    ) -> DAppOperationConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chain.chainId),
            let currencyManager = CurrencyManager.shared,
            let account = request.wallet.fetch(for: chain.accountRequest())
        else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let substrateStorageFacade = SubstrateDataStorageFacade.shared

        let extrinsicFeeHost = ExtrinsicFeeEstimatorHost(
            account: account,
            chain: chain,
            connection: connection,
            runtimeProvider: runtimeProvider,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: substrateStorageFacade,
            operationQueue: operationQueue
        )

        let feeEstimationRegistry = ExtrinsicFeeEstimationRegistry(
            chain: chain,
            estimatingWrapperFactory: ExtrinsicFeeEstimatingWrapperFactory(
                host: extrinsicFeeHost,
                customFeeEstimatorFactory: AssetConversionFeeEstimatingFactory(host: extrinsicFeeHost)
            ),
            feeInstallingWrapperFactory: AssetConversionFeeInstallingFactory(host: extrinsicFeeHost)
        )

        let metadataHashFactory = MetadataHashOperationFactory(
            metadataRepositoryFactory: RuntimeMetadataRepositoryFactory(storageFacade: substrateStorageFacade),
            operationQueue: operationQueue
        )

        return DAppOperationConfirmInteractor(
            request: request,
            chain: chain,
            runtimeProvider: runtimeProvider,
            feeEstimationRegistry: feeEstimationRegistry,
            connection: connection,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            metadataHashFactory: metadataHashFactory,
            userStorageFacade: UserDataStorageFacade.shared,
            priceProviderFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: operationQueue
        )
    }

    static func createSignBytesInteractor(
        for request: DAppOperationRequest,
        chain: ChainModel
    ) -> DAppSignBytesConfirmInteractor {
        DAppSignBytesConfirmInteractor(
            request: request,
            chain: chain,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            serializationFactory: PolkadotExtensionMessageSignFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    static func createEthereumInteractor(
        for request: DAppOperationRequest,
        chain: Either<ChainModel, DAppUnknownChain>,
        validationProviderFactory: EvmValidationProviderFactoryProtocol,
        shouldSendTransaction: Bool
    ) -> DAppEthereumConfirmInteractor? {
        let operationFactory: EthereumOperationFactoryProtocol
        let chainId: String

        switch chain {
        case let .left(knownChain):
            guard
                let connection = ChainRegistryFacade.sharedRegistry.getOneShotConnection(
                    for: knownChain.chainId
                ) else {
                return nil
            }

            operationFactory = EvmWebSocketOperationFactory(connection: connection)
            chainId = BigUInt(knownChain.addressPrefix).toHexString()
        case let .right(unknownChain):
            guard let connection = HTTPEngine(
                urls: [unknownChain.rpcUrl],
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ) else {
                return nil
            }

            operationFactory = EvmWebSocketOperationFactory(connection: connection)
            chainId = unknownChain.chainId
        }

        return DAppEthereumConfirmInteractor(
            chainId: chainId,
            request: request,
            ethereumOperationFactory: operationFactory,
            validationProviderFactory: validationProviderFactory,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            signingWrapperFactory: SigningWrapperFactory(keystore: Keychain()),
            shouldSendTransaction: shouldSendTransaction
        )
    }

    static func createEthereumPersonalSignInteractor(
        for request: DAppOperationRequest
    ) -> DAppEthereumSignBytesInteractor {
        DAppEthereumSignBytesInteractor(
            request: request,
            signingWrapperFactory: SigningWrapperFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
