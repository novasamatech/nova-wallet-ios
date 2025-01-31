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
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let interactor = MythosStkYourCollatorsInteractor()
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
            localizationManager: LocalizationManager.shared
        )

        let view = CollatorStkYourCollatorsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
