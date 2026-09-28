import Foundation
import Foundation_iOS
import Operation_iOS

enum SubtensorStakingConfirmViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        model: SubtensorStakingConfirmModel
    ) -> SubtensorStakingConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let services = SubtensorFlowServicesFactory.createServices(for: state),
            services.isFlowAccount(model.account) else {
            return nil
        }

        let interactor = createInteractor(for: state, services: services)
        let selectedAccount = services.account
        let currencyManager = services.currencyManager

        let wireframe = SubtensorStakingConfirmWireframe(state: state)

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

        let presenter = SubtensorStakingConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            model: model,
            dataValidationFactory: dataValidationFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            quoteViewModelFactory: SubtensorQuoteViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let screenTitle = CollatorStakingStakeScreenTitle.confirm(hasStake: model.origin != .newPosition)

        let view: SubtensorStakingConfirmViewProtocol = SubtensorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: screenTitle(),
            statics: .subtensorValidator,
            isRoot: model.target.isRoot,
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
    ) -> SubtensorStakingConfirmInteractor {
        SubtensorStakingConfirmInteractor(
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
            runtimeProvider: services.runtimeProvider,
            currencyManager: services.currencyManager,
            operationQueue: services.operationQueue,
            logger: Logger.shared
        )
    }
}
