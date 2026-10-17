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
            chainAsset: state.stakingOption.chainAsset,
            pendingRootClaims: state.flowState.pendingRootClaims,
            interactor: interactor,
            wireframe: SubtensorPositionWireframe(state: state),
            viewModelFactory: SubtensorPositionViewModelFactory(
                chainAsset: state.stakingOption.chainAsset,
                priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
            ),
            localizationManager: LocalizationManager.shared
        )

        let singleTapHapticPlayer = HapticPlayerFactory.createHapticPlayer(patternConfiguration: .singleTap)

        let view = SubtensorPositionViewController(
            presenter: presenter,
            isRoot: group.netuid == SubtensorStakingPallet.rootNetuid,
            seekHapticPlayer: HapticPlayerFactory.createProgressivePlayer(patternConfiguration: .chartSeek),
            chartLongPressHapticPlayer: singleTapHapticPlayer,
            periodControlHapticPlayer: singleTapHapticPlayer,
            localizationManager: LocalizationManager.shared
        )

        interactor.presenter = presenter
        presenter.view = view

        return view
    }
}
