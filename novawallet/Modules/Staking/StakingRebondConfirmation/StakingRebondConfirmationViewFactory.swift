import Foundation
import Foundation_iOS
import Keystore_iOS
import Operation_iOS
import SubstrateSdk

struct StakingRebondConfirmationViewFactory {
    static func createView(
        for variant: SelectedRebondVariant,
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRebondConfirmationViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(state: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = StakingRebondConfirmationWireframe()

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)

        let presenter = createPresenter(
            for: variant,
            interactor: interactor,
            wireframe: wireframe,
            dataValidatingFactory: dataValidatingFactory,
            chainAsset: chainAsset,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let view = StakingRebondConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPresenter(
        for variant: SelectedRebondVariant,
        interactor: StakingRebondConfirmationInteractorInputProtocol,
        wireframe: StakingRebondConfirmationWireframeProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> StakingRebondConfirmationPresenter {
        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let confirmationViewModelFactory = StakingRebondConfirmationViewModelFactory()

        return StakingRebondConfirmationPresenter(
            variant: variant,
            interactor: interactor,
            wireframe: wireframe,
            confirmViewModelFactory: confirmationViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            chain: chainAsset.chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )
    }

    private static func createInteractor(
        state: RelaychainStakingSharedStateProtocol
    ) -> StakingRebondConfirmationInteractor? {
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

        return StakingRebondConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            accountRepositoryFactory: accountRepositoryFactory,
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapperFactory: SigningWrapperFactory(),
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            feeProxy: feeProxy,
            operationManager: operationManager,
            currencyManager: currencyManager
        )
    }
}
