import Foundation
import SoraFoundation
import RobinHood

struct StakingSetupAmountViewFactory {
    static func createView(
        for state: RelaychainStartStakingStateProtocol
    ) -> StakingSetupAmountViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let chainAsset = state.chainAsset

        guard let currencyManager = CurrencyManager.shared,
              let metaAccount = SelectedWalletSettings.shared.value,
              let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
              let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
              let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
            return nil
        }

        let rewardCalculationService = state.relaychainRewardCalculatorService

        let networkInfoOperationFactory = state.createNetworkInfoOperationFactory(
            for: OperationManagerFacade.sharedDefaultQueue
        )

        let validatorService = state.eraValidatorService

        let walletLocalSubscriptionFactory = WalletLocalSubscriptionFactory.shared
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        let operationQueue = OperationQueue()
        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: OperationManager(operationQueue: operationQueue)
        ).createService(account: selectedAccount, chain: chainAsset.chain)

        let interactor = StakingSetupAmountInteractor(
            selectedAccount: selectedAccount,
            selectedChainAsset: chainAsset,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            stakingLocalSubscriptionFactory: state.relaychainLocalSubscriptionFactory,
            currencyManager: currencyManager,
            runtimeProvider: runtimeService,
            extrinsicService: extrinsicService,
            rewardService: rewardCalculationService,
            networkInfoOperationFactory: networkInfoOperationFactory,
            eraValidatorService: validatorService,
            operationQueue: operationQueue
        )
        let wireframe = StakingSetupAmountWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let viewModelFactory = StakingAmountViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            estimatedEarningsFormatter: NumberFormatter.percentBase.localizableResource()
        )
        let chainAssetViewModelFactory = ChainAssetViewModelFactory(networkViewModelFactory: NetworkViewModelFactory())

        let presenter = StakingSetupAmountPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAssetViewModelFactory: chainAssetViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = StakingSetupAmountViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
