import Foundation
import Operation_iOS
import Foundation_iOS
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

        let wireframe = MythosStakingDetailsWireframe(state: sharedState)

        // MARK: - Presenter

        let priceAssetInfo = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = MythosStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfo)

        let networkInfoFactory = CollatorStkNetworkInfoViewModelFactory(priceAssetInfoFactory: priceAssetInfo)

        let presenter = MythosStakingDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            networkInfoViewModelFactory: networkInfoFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return presenter
    }

    func createMythosInteractor(state: MythosStakingSharedStateProtocol) -> MythosStakingDetailsInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let blockTimeOperationFactory = BlockTimeOperationFactory(chain: chainAsset.chain)

        let durationFactory = MythosStkDurationOperationFactory(
            chainRegistry: state.chainRegistry,
            blockTimeOperationFactory: blockTimeOperationFactory
        )

        let networkInfoFactory = MythosStkNetworkInfoOperationFactory(
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        return MythosStakingDetailsInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            networkInfoFactory: networkInfoFactory,
            durationOperationFactory: durationFactory,
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
