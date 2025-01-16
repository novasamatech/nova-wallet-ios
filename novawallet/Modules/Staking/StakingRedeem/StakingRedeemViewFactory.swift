import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

final class StakingRedeemViewFactory {
    static func createView(for state: RelaychainStakingSharedStateProtocol) -> StakingRedeemViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(state: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingRedeemWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = createPresenter(
            from: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let view = StakingRedeemViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPresenter(
        from interactor: StakingRedeemInteractorInputProtocol,
        wireframe: StakingRedeemWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> StakingRedeemPresenter {
        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let confirmationViewModelFactory = StakingRedeemViewModelFactory()

        return StakingRedeemPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            chain: chainAsset.chain,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRedeemInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetch(
                for: chainAsset.chain.accountRequest()
            ),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        return StakingRedeemInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            chainRegistry: chainRegistry,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: SigningWrapperFactory(),
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            slashesOperationFactory: SlashesOperationFactory(storageRequestFactory: storageRequestFactory),
            feeProxy: feeProxy,
            operationManager: operationManager,
            currencyManager: currencyManager
        )
    }
}
