import Foundation
import Foundation_iOS

struct CrowdloanUnlockViewFactory {
    static func createView(
        for state: CrowdloanSharedState,
        unlockModel: CrowdloanUnlock
    ) -> CrowdloanUnlockViewProtocol? {
        guard
            let chain = state.settings.value,
            let chainAsset = chain.utilityChainAsset(),
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                selectedAccount: selectedAccount,
                chainAsset: chainAsset,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = CrowdloanUnlockWireframe()

        let assetInfo = chainAsset.assetDisplayInfo
        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let dataValidatingFactory = CrowdloanDataValidatingFactory(presentable: wireframe)

        let presenter = CrowdloanUnlockPresenter(
            interactor: interactor,
            wireframe: wireframe,
            unlockModel: unlockModel,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CrowdloanUnlockViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

private extension CrowdloanUnlockViewFactory {
    static func createInteractor(
        for state: CrowdloanSharedState,
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol
    ) -> CrowdloanUnlockInteractor? {
        guard
            let runtimeService = state.chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ),
            let connection = state.chainRegistry.getConnection(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let extrinsicFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: operationQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let extrinsicService = extrinsicFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        let signingWrapper = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let submissionMonitor = extrinsicFactory.createExtrinsicSubmissionMonitor(with: extrinsicService)

        return CrowdloanUnlockInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            extrinsicService: extrinsicService,
            submissionMonitor: submissionMonitor,
            signingWrapper: signingWrapper,
            runtimeService: runtimeService,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager,
            logger: Logger.shared
        )
    }
}
