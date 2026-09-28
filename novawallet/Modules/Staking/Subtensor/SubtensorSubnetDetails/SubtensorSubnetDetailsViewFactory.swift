import Foundation
import Foundation_iOS

enum SubtensorSubnetDetailsViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        model: SubtensorSubnetSelectViewModel,
        delegate: SubtensorSubnetSelectDelegate
    ) -> SubtensorSubnetDetailsViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = SubtensorSubnetDetailsInteractor(
            priceHistoryService: state.earnServices.priceHistoryService,
            recommendationService: state.earnServices.recommendationService,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let presenter = SubtensorSubnetDetailsPresenter(
            model: model,
            selectionDelegate: delegate,
            interactor: interactor,
            wireframe: SubtensorSubnetDetailsWireframe(state: state),
            earnSettings: state.earnServices.earnSettings,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
        let view = SubtensorSubnetDetailsViewController(
            presenter: presenter,
            target: model.target,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
