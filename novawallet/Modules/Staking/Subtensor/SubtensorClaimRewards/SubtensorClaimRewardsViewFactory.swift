import Foundation
import Foundation_iOS

enum SubtensorClaimRewardsViewFactory {
    static func createView(
        for state: SubtensorSharedStateProtocol,
        model: SubtensorClaimRewardsModel
    ) -> SubtensorClaimRewardsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let services = SubtensorFlowServicesFactory.createServices(for: state, observesBlocks: false),
            services.isFlowAccount(model.account) else {
            return nil
        }

        let interactor = SubtensorBaseInteractor(flowServices: services, state: state, logger: Logger.shared)

        let wireframe = SubtensorConfirmWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)

        let dataValidationFactory = SubtensorValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorClaimRewardsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            model: model,
            pendingRootClaims: state.flowState.pendingRootClaims,
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
        interactor.basePresenter = presenter
        dataValidationFactory.view = view

        return view
    }
}
