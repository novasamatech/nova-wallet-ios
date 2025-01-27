import Foundation
import Operation_iOS
import SoraFoundation
import SubstrateSdk

extension StakingMainPresenterFactory {
    func createMythosPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> MythosStakingDetailsPresenter? {
        guard let sharedState = try? sharedStateFactory.createMythosStaking(for: stakingOption) else {
            return nil
        }

        // MARK: - Interactor

        guard let interactor = createMythosInteractor(state: sharedState),
              let currencyManager = CurrencyManager.shared else {
            return nil
        }

        // MARK: - Router

        let wireframe = MythosStakingDetailsWireframe()

        // MARK: - Presenter

        let presenter = MythosStakingDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createMythosInteractor(state: MythosStakingSharedStateProtocol) -> MythosStakingDetailsInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetch(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        return MythosStakingDetailsInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
