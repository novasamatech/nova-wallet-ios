import Foundation
import SoraFoundation

struct MythosStkYourCollatorsViewFactory {
    static func createView(
        for state: MythosStakingSharedStateProtocol
    ) -> CollatorStkYourCollatorsViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(for: state, chainAsset: chainAsset) else {
            return nil
        }

        let wireframe = MythosStkYourCollatorsWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let priceInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceInfoFactory
        )

        let viewModelFactory = CollatorStkYourCollatorsViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory,
            assetPrecision: assetInfo.assetPrecision,
            chainFormat: chainAsset.chain.chainFormat
        )

        let presenter = MythosStkYourCollatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            selectedAccount: selectedAccount,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = CollatorStkYourCollatorsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        for state: MythosStakingSharedStateProtocol,
        chainAsset _: ChainAsset
    ) -> MythosStkYourCollatorsInteractor? {
        guard let detailsService = state.detailsSyncService else {
            return nil
        }
        
        return MythosStkYourCollatorsInteractor(
            stakingDetailsService: state.detailsSyncService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
