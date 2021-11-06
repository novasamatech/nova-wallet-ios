import Foundation
import SoraFoundation
import SubstrateSdk
import SoraKeystore
import RobinHood

struct ControllerAccountConfirmationViewFactory {
    static func createView(
        for state: StakingSharedState,
        controllerAccountItem: AccountItem
    ) -> ControllerAccountConfirmationViewProtocol? {
        guard
            let chainAsset = state.settings.value,
            let interactor = createInteractor(
                for: state,
                controllerAccountItem: controllerAccountItem
            ) else {
            return nil
        }

        let wireframe = ControllerAccountConfirmationWireframe()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let dataValidatingFactory = StakingDataValidatingFactory(presentable: wireframe)
        let presenter = ControllerAccountConfirmationPresenter(
            controllerAccountItem: controllerAccountItem,
            assetInfo: assetInfo,
            iconGenerator: PolkadotIconGenerator(),
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            explorers: chainAsset.chain.explorers
        )

        let view = ControllerAccountConfirmationVC(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for state: StakingSharedState,
        controllerAccountItem: AccountItem
    ) -> ControllerAccountConfirmationInteractor? {
        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = state.settings.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let facade = UserDataStorageFacade.shared
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: facade)

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signingWrapper = SigningWrapper(
            keystore: Keychain(),
            metaId: metaAccount.metaId,
            accountResponse: selectedAccount
        )

        let interactor = ControllerAccountConfirmationInteractor(
            selectedAccount: selectedAccount,
            controllerAccountItem: controllerAccountItem,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            runtimeService: runtimeService,
            connection: connection,
            accountRepositoryFactory: accountRepositoryFactory,
            feeProxy: ExtrinsicFeeProxy(),
            extrinsicServiceFactory: extrinsicServiceFactory,
            signingWrapper: signingWrapper,
            storageRequestFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return interactor
    }
}
