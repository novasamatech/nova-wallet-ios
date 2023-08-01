import Foundation
import SoraFoundation
import RobinHood

struct StakingSetupAmountViewFactory {
    static func createView(chainAsset: ChainAsset, state: StakingSharedState) -> StakingSetupAmountViewProtocol? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard let currencyManager = CurrencyManager.shared,
              let metaAccount = SelectedWalletSettings.shared.value,
              let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()),
              let mataChainAccount = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
              let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
              let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
              let rewardCalculationService = state.rewardCalculationService,
              let networkInfoOperationFactory = try? state.createNetworkInfoOperationFactory(
                  for: chainAsset.chain
              ),
              let validatorService = state.eraValidatorService else {
            return nil
        }

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
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
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
