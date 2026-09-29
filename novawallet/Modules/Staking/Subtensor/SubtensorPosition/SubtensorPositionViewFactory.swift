import Foundation
import Foundation_iOS

enum SubtensorPositionViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        group: SubtensorPortfolioGroup
    ) -> SubtensorPositionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = SubtensorPositionInteractor(
            state: state,
            netuid: group.netuid,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let presenter = SubtensorPositionPresenter(
            group: group,
            account: state.selectedAccount,
            interactor: interactor,
            wireframe: SubtensorPositionWireframe(state: state),
            precision: Int16(state.stakingOption.chainAsset.asset.precision),
            localizationManager: LocalizationManager.shared
        )
        let view = SubtensorPositionViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        interactor.presenter = presenter
        presenter.view = view
        return view
    }
}
