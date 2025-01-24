import Foundation
import SoraFoundation

struct ParaStkCollatorInfoViewFactory {
    static func createView(
        for interactor: CollatorStakingInfoInteractor,
        chainAsset: ChainAsset,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> ParaStkCollatorInfoViewProtocol? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let wireframe = ParaStkCollatorInfoWireframe()

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let viewModelFactory = ParaStkCollatorInfoViewModelFactory(
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
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
