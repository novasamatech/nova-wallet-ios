import Foundation
import SoraFoundation

struct ParaStkCollatorInfoViewFactory {
    static func createView(
        for state: ParachainStakingSharedState,
        collatorInfo: CollatorSelectionInfo
    ) -> ParaStkCollatorInfoViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let interactor = ParaStkCollatorInfoInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            currencyManager: currencyManager
        )

        let wireframe = ParaStkCollatorInfoWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let viewModelFactory = ParaStkCollatorInfoViewModelFactory(
            balanceViewModelFactory: BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo),
            precision: assetDisplayInfo.assetPrecision,
            chainFormat: chainAsset.chain.chainFormat
        )

        let presenter = ParaStkCollatorInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chainAsset.chain,
            selectedAccount: selectedAccount,
            collatorInfo: collatorInfo,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkCollatorInfoViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
