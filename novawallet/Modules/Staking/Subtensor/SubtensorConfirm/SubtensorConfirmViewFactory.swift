import Foundation
import Foundation_iOS
import Operation_iOS

enum SubtensorConfirmViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        model: SubtensorConfirmModel
    ) -> SubtensorConfirmViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let services = SubtensorFlowServicesFactory.createServices(for: state),
            services.isFlowAccount(model.account) else {
            return nil
        }

        let interactor = SubtensorConfirmInteractor(flowServices: services, state: state, logger: Logger.shared)

        let wireframe = SubtensorConfirmWireframe(state: state)

        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: services.currencyManager)

        let dataValidationFactory = SubtensorStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorConfirmPresenter(
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

        let view = SubtensorConfirmViewController(
            presenter: presenter,
            mode: createViewMode(for: model),
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

        return view
    }

    private static func createViewMode(for model: SubtensorConfirmModel) -> SubtensorConfirmViewLayout.Mode {
        guard model.target.isRoot else {
            return .swap(model.direction)
        }

        return model.direction == .buy ? .rootStake : .rootUnstake
    }
}
