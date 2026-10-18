import Foundation
import Foundation_iOS

enum SubtensorPositionViewFactory {
    static func createView(
        for state: SubtensorStakingSharedStateProtocol,
        group: SubtensorPortfolioGroup
    ) -> SubtensorPositionViewProtocol? {
        guard let currencyManager = CurrencyManager.shared else { return nil }

        let isRoot = group.netuid == SubtensorStakingPallet.rootNetuid

        let interactor = SubtensorPositionInteractor(
            state: state,
            netuid: group.netuid,
            blockNumberSubscription: isRoot ? SubtensorFlowServicesFactory.createBlockSubscription(for: state) : nil,
            applicationHandler: ApplicationHandler(),
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        let presenter = SubtensorPositionPresenter(
            group: group,
            account: state.selectedAccount,
            chainAsset: state.stakingOption.chainAsset,
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
            isRoot: isRoot,
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
