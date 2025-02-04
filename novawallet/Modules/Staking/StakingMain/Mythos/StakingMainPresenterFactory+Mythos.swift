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

        let wireframe = MythosStakingDetailsWireframe(state: sharedState)

        // MARK: - Presenter

        let priceAssetInfo = PriceAssetInfoFactory(currencyManager: currencyManager)

        let viewModelFactory = MythosStkStateViewModelFactory(priceAssetInfoFactory: priceAssetInfo)

        let dataValidationFactory = MythosStakingValidationFactory(
            presentable: wireframe,
            assetDisplayInfo: stakingOption.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfo
        )

        let presenter = MythosStakingDetailsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            dataValidationFactory: dataValidationFactory,
            logger: Logger.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidationFactory.view = view

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

        return MythosStakingDetailsInteractor(
            selectedAccount: selectedAccount,
            sharedState: state,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
    }
}
