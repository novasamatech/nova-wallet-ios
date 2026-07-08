import Foundation
import Foundation_iOS
import UIKit
import BigInt

enum SubtensorUnstakeSetupViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        subnetName: String? = nil
    ) -> UIViewController? {
        guard
            let selectedWallet = SelectedWalletSettings.shared.value,
            let selectedAccount = selectedWallet
            .fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared
        else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let interactor = SubtensorUnstakeSetupInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            position: position,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let wireframe = SubtensorUnstakeSetupWireframe()
        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorUnstakeSetupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            position: position,
            balanceViewModelFactory: balanceViewModelFactory,
            localizationManager: localizationManager
        )

        let view = SubtensorUnstakeSetupViewController(
            presenter: presenter,
            netuid: position.netuid,
            subnetName: subnetName,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
