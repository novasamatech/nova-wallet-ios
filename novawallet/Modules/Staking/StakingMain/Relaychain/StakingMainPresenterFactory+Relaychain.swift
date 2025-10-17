import Foundation
import Operation_iOS
import SubstrateSdk
import Foundation_iOS
import Keystore_iOS

extension StakingMainPresenterFactory {
    func createRelaychainPresenter(
        for stakingOption: Multistaking.ChainAssetOption,
        view: StakingMainViewProtocol
    ) -> StakingRelaychainPresenter? {
        // MARK: - Interactor

        guard
            let sharedState = try? sharedStateFactory.createRelaychain(for: stakingOption),
            let interactor = createRelaychainInteractor(state: sharedState),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        // MARK: - Router

        let wireframe = StakingRelaychainWireframe(state: sharedState)
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        // MARK: - Presenter

        let viewModelFacade = StakingViewModelFacade()

        let logger = Logger.shared

        let stateViewModelFactory = StakingStateViewModelFactory(
            priceAssetInfoFactory: priceAssetInfoFactory,
            logger: logger
        )
        let networkInfoViewModelFactory = NetworkInfoViewModelFactory(priceAssetInfoFactory: priceAssetInfoFactory)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = StakingRelaychainPresenter(
            stateViewModelFactory: stateViewModelFactory,
            networkInfoViewModelFactory: networkInfoViewModelFactory,
            viewModelFacade: viewModelFacade,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: logger
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        dataValidatingFactory.view = view

        return presenter
    }

    func createRelaychainInteractor(
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRelaychainInteractor? {
        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let accountProviderFactory = AccountProviderFactory(
            storageFacade: UserDataStorageFacade.shared,
            operationManager: operationManager,
            logger: logger
        )

        let networkInfoFactory = state.createNetworkInfoOperationFactory(
            for: OperationManagerFacade.sharedDefaultQueue
        )

        let eraCountdownFactory = state.createEraCountdownOperationFactory(
            for: OperationManagerFacade.sharedDefaultQueue
        )

        return StakingRelaychainInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            sharedState: state,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            accountProviderFactory: accountProviderFactory,
            networkInfoOperationFactory: networkInfoFactory,
            eraCountdownOperationFactory: eraCountdownFactory,
            eventCenter: EventCenter.shared,
            operationManager: operationManager,
            applicationHandler: applicationHandler,
            currencyManager: currencyManager,
            logger: logger
        )
    }
}
