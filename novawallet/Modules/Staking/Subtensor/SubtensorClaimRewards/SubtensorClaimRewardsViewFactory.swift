import Foundation
import Foundation_iOS
import Operation_iOS

enum SubtensorClaimRewardsViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol
    ) -> StakingGenericRewardsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let services = SubtensorFlowServicesFactory.createServices(for: state) else {
            return nil
        }

        let interactor = createInteractor(for: state, services: services)
        let selectedAccount = services.account
        let currencyManager = services.currencyManager

        let wireframe = SubtensorClaimRewardsWireframe()

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorClaimRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorClaimRewardsViewController(
            basePresenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: SubtensorStakingSharedStateProtocol,
        services: SubtensorFlowServices
    ) -> SubtensorClaimRewardsInteractor {
        SubtensorClaimRewardsInteractor(
            chainAsset: state.stakingOption.chainAsset,
            selectedAccount: services.account.chainAccount,
            positionsSyncService: services.positionsSyncService,
            rootClaimableService: services.rootClaimableService,
            preflightFactory: services.preflightFactory,
            tradeQuoteFactory: services.tradeQuoteFactory,
            operationService: services.operationService,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            extrinsicService: services.extrinsicService,
            extrinsicSubmitMonitor: services.extrinsicSubmitMonitor,
            signer: services.signer,
            sharedOperation: state.sharedOperation,
            runtimeProvider: services.runtimeProvider,
            currencyManager: services.currencyManager,
            operationQueue: services.operationQueue,
            logger: Logger.shared
        )
    }
}
