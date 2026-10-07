import Foundation
import Foundation_iOS

enum SubtensorClaimRewardsViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        model: SubtensorClaimRewardsModel
    ) -> SubtensorClaimRewardsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let services = SubtensorFlowServicesFactory.createServices(for: state),
            services.isFlowAccount(model.account) else {
            return nil
        }

        let interactor = SubtensorClaimRewardsInteractor(
            baseServices: services,
            chainAsset: chainAsset,
            claimableFetchFactory: SubtensorRootClaimableFetchFactory(
                operationFactory: state.apiOperationFactory,
                operationQueue: services.operationQueue
            ),
            catalogueService: state.earnServices.catalogueService,
            costBasisService: state.earnServices.costBasisService,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            logger: Logger.shared
        )

        let wireframe = SubtensorClaimRewardsWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorClaimRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            model: model,
            pendingRootClaims: state.pendingRootClaims,
            viewModelFactory: SubtensorClaimRewardsViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            dataValidationFactory: dataValidationFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorClaimRewardsViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }
}
