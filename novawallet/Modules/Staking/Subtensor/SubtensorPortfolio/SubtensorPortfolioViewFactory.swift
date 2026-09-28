import Foundation
import Foundation_iOS

enum SubtensorPortfolioViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        stakingState: Multistaking.SubtensorStakingState,
        commonData: SubtensorStakingCommonData
    ) -> SubtensorPortfolioViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let interactor = SubtensorPortfolioInteractor(
            state: state,
            currencyManager: currencyManager,
            coingeckoFactory: CoingeckoOperationFactory(),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let presenter = SubtensorPortfolioPresenter(
            state: stakingState,
            commonData: commonData,
            interactor: interactor,
            wireframe: SubtensorPortfolioWireframe(state: state),
            precision: Int16(state.stakingOption.chainAsset.asset.precision),
            localizationManager: LocalizationManager.shared
        )
        let view = SubtensorPortfolioViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )
        presenter.view = view
        interactor.presenter = presenter
        return view
    }
}
