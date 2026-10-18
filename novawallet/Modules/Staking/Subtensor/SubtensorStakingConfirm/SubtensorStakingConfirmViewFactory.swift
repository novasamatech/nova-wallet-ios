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

        let interactor = SubtensorStakingConfirmInteractor(
            baseServices: services,
            chainAsset: chainAsset,
            catalogueService: state.earnServices.catalogueService,
            subnetLogosProvider: state.earnServices.subnetLogosProvider,
            costBasisService: state.earnServices.costBasisService,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            logger: Logger.shared
        )

        let wireframe = SubtensorStakingConfirmWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakingConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            model: model,
            viewModelFactory: SubtensorConfirmViewModelFactory(
                chainAsset: chainAsset,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            dataValidationFactory: dataValidationFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = SubtensorStakingConfirmViewController(
            presenter: presenter,
            mode: model.target.isRoot ? .rootStake : .swap(.buy),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }
}
