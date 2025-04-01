import Foundation
import Foundation_iOS

struct CollatorStakingInfoViewFactory {
    static func createView(
        for interactor: CollatorStakingInfoInteractor,
        chainAsset: ChainAsset,
        collatorInfo: CollatorStakingSelectionInfoProtocol,
        currencyManager: CurrencyManagerProtocol
    ) -> CollatorStakingInfoViewProtocol? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let wireframe = CollatorStakingInfoWireframe()

        let localizationManager = LocalizationManager.shared
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let assetDisplayInfo = chainAsset.assetDisplayInfo
        let viewModelFactory = CollatorStakingInfoViewModelFactory(
            balanceViewModelFactory: BalanceViewModelFactory(
                targetAssetInfo: assetDisplayInfo,
                priceAssetInfoFactory: priceAssetInfoFactory
            ),
            precision: assetDisplayInfo.assetPrecision,
            chainFormat: chainAsset.chain.chainFormat
        )

        let presenter = CollatorStakingInfoPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chain: chainAsset.chain,
            selectedAccount: selectedAccount,
            collatorInfo: collatorInfo,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = CollatorStakingInfoViewController(presenter: presenter, localizationManager: localizationManager)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
