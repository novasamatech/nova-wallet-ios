import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

struct StakingBondMoreViewFactory {
    static func createView(from state: RelaychainStakingSharedStateProtocol) -> StakingBondMoreViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let wallet = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = wallet.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        guard let interactor = createInteractor(selectedAccount: selectedAccount, state: state) else {
            return nil
        }

        let wireframe = StakingBondMoreWireframe(state: state)

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = StakingBondMorePresenter(
            interactor: interactor,
            wireframe: wireframe,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            logger: Logger.shared
        )

        let viewController = StakingBondMoreViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = viewController
        interactor.presenter = presenter
        dataValidatingFactory.view = viewController

        return viewController
    }

    private static func createInteractor(
        selectedAccount: ChainAccountResponse,
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingBondMoreInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.stakingOption.chainAsset

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeRegistry = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeRegistry,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let feeProxy = ExtrinsicFeeProxy()

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let interactor = StakingBondMoreInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            feeProxy: feeProxy,
            runtimeProvider: runtimeRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            currencyManager: currencyManager
        )

        return interactor
    }
}
