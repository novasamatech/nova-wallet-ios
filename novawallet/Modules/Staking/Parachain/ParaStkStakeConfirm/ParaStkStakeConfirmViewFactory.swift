import Foundation
import SoraFoundation

struct ParaStkStakeConfirmViewFactory {
    static func createView(
        for state: ParachainStakingSharedState,
        collator: DisplayAddress,
        amount: Decimal
    ) -> ParaStkStakeConfirmViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest())
        else {
            return nil
        }

        let interactor = ParaStkStakeConfirmInteractor()
        let wireframe = ParaStkStakeConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetDisplayInfo)

        let presenter = ParaStkStakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            collator: collator,
            amount: amount,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ParaStkStakeConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
