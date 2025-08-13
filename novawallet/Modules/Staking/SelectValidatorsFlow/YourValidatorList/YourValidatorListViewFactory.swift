import Foundation
import Foundation_iOS
import Operation_iOS
import Keystore_iOS
import SubstrateSdk

struct YourValidatorListViewFactory {
    static func createView(for state: RelaychainStakingSharedStateProtocol) -> YourValidatorListViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let interactor = createInteractor(state: state),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let wireframe = YourValidatorListWireframe(state: state)

        let chainInfo = chainAsset.chainAssetInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainInfo.asset,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let viewModelFactory = YourValidatorListViewModelFactory(
            balanceViewModeFactory: balanceViewModelFactory
        )

        let presenter = YourValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainInfo: chainInfo,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = YourValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(state: RelaychainStakingSharedStateProtocol) -> YourValidatorListInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let eraValidatorService = state.eraValidatorService
        let rewardCalculationService = state.rewardCalculatorService

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let operationManager = OperationManagerFacade.sharedManager

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(
                for: chainAsset.chain.chainId
            ) else {
            return nil
        }

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let keyFactory = StorageKeyFactory()
        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: keyFactory,
            operationManager: operationManager
        )

        let identityProxyFactory = IdentityProxyFactory(
            originChain: chainAsset.chain,
            chainRegistry: chainRegistry,
            identityOperationFactory: IdentityOperationFactory(requestFactory: storageRequestFactory)
        )

        let validatorOperationFactory = ValidatorOperationFactory(
            chainInfo: chainAsset.chainAssetInfo,
            eraValidatorService: eraValidatorService,
            rewardService: rewardCalculationService,
            storageRequestFactory: storageRequestFactory,
            runtimeService: runtimeService,
            engine: connection,
            identityProxyFactory: identityProxyFactory,
            slashesOperationFactory: SlashesOperationFactory(
                storageRequestFactory: storageRequestFactory,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            )
        )

        return YourValidatorListInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            accountRepositoryFactory: accountRepositoryFactory,
            eraValidatorService: eraValidatorService,
            validatorOperationFactory: validatorOperationFactory,
            operationManager: operationManager
        )
    }
}
