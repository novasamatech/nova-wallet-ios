import Foundation
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

enum SubtensorStakingSetupViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        initialPosition: SubtensorStakingPosition?
    ) -> CollatorStakingSetupViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let interactor = createInteractor(for: state, services: services, initialPosition: initialPosition)
        let selectedAccount = services.account
        let currencyManager = services.currencyManager

        let wireframe = SubtensorStakingSetupWireframe(state: state)

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let accountDetailsFactory = CollatorStakingAccountViewModelFactory(chainAsset: chainAsset)

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            accountDetailsViewModelFactory: accountDetailsFactory,
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            initialPosition: initialPosition,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let localizableTitle = CollatorStakingStakeScreenTitle.setup(
            hasStake: initialPosition != nil,
            assetSymbol: chainAsset.asset.symbol
        )

        let view = SubtensorStakingSetupViewController(
            presenter: presenter,
            localizableTitle: localizableTitle(),
            statics: .subtensorValidator,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        services: SubtensorFlowServices,
        initialPosition: SubtensorStakingPosition?
    ) -> SubtensorStakingSetupInteractor {
        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManager(operationQueue: services.operationQueue)
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: state.stakingOption.chainAsset.chain,
            chainRegistry: state.chainRegistry,
            identityOperationFactory: IdentityOperationFactory(requestFactory: requestFactory)
        )

        return SubtensorStakingSetupInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: services.account.chainAccount,
            positionsSyncService: services.positionsSyncService,
            rootClaimableService: services.rootClaimableService,
            preflightFactory: services.preflightFactory,
            tradeQuoteFactory: services.tradeQuoteFactory,
            operationService: services.operationService,
            rewardCalculatorService: state.rewardCalculatorService,
            subnetsService: state.subnetsService,
            initialNetuid: initialPosition?.netuid,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            runtimeProvider: services.runtimeProvider,
            identityProxyFactory: identityProxyFactory,
            currencyManager: services.currencyManager,
            operationQueue: services.operationQueue,
            logger: Logger.shared
        )
    }
}
