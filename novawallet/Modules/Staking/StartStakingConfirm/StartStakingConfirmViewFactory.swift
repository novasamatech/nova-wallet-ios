import Foundation
import Foundation_iOS
import Keystore_iOS

struct StartStakingConfirmViewFactory {
    static func createView(
        for stakingOption: SelectedStakingOption,
        amount: Decimal,
        state: RelaychainStartStakingStateProtocol
    ) -> StartStakingConfirmViewProtocol? {
        guard
            let selectedAccount = SelectedWalletSettings.shared.value.fetchMetaChainAccount(
                for: state.chainAsset.chain.accountRequest()
            ),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        switch stakingOption {
        case let .direct(preparedValidators):
            return createDirectStakingView(
                for: preparedValidators,
                amount: amount,
                state: state,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            )
        case let .pool(selectedPool):
            return createPoolStakingView(
                for: selectedPool,
                amount: amount,
                state: state,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            )
        }
    }

    private static func createDirectStakingView(
        for validators: PreparedValidators,
        amount: Decimal,
        state: RelaychainStartStakingStateProtocol,
        selectedAccount: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingConfirmViewProtocol? {
        guard
            let interactor = createInteractor(
                for: .direct(validators),
                amount: amount,
                state: state,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = StartStakingDirectConfirmWireframe(stakingState: state)

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StartStakingDirectConfirmPresenter(
            model: validators,
            interactor: interactor,
            wireframe: wireframe,
            amount: amount,
            chainAsset: state.chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            quantityFormatter: NumberFormatter.quantity.localizableResource(),
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StartStakingConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createPoolStakingView(
        for pool: NominationPools.SelectedPool,
        amount: Decimal,
        state: RelaychainStartStakingStateProtocol,
        selectedAccount: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingConfirmViewProtocol? {
        guard
            let interactor = createInteractor(
                for: .pool(pool),
                amount: amount,
                state: state,
                selectedAccount: selectedAccount,
                currencyManager: currencyManager
            ) else {
            return nil
        }

        let wireframe = StartStakingConfirmWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: state.chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StartStakingPoolConfirmPresenter(
            model: pool,
            interactor: interactor,
            wireframe: wireframe,
            amount: amount,
            chainAsset: state.chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = StartStakingConfirmViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInteractor(
        for stakingOption: SelectedStakingOption,
        amount: Decimal,
        state: RelaychainStartStakingStateProtocol,
        selectedAccount: MetaChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) -> StartStakingConfirmInteractor? {
        guard
            let amountInPlank = amount.toSubstrateAmount(
                precision: state.chainAsset.assetDisplayInfo.assetPrecision
            ) else {
            return nil
        }

        let chainId = state.chainAsset.chain.chainId

        guard
            let runtimeService = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId) else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: state.chainAsset.chain)

        let signer = SigningWrapperFactory(keystore: Keychain()).createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        let extrinsicProxy = StartStakingExtrinsicProxy(
            selectedAccount: selectedAccount.chainAccount,
            runtimeService: runtimeService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        guard let restrictionsBuilder = createRestrictionsBuilder(for: stakingOption, state: state) else {
            return nil
        }

        let extrinsicMonitorFactory = ExtrinsicSubmissionMonitorFactory(
            submissionService: extrinsicService,
            connection: connection,
            runtimeService: runtimeService,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        return .init(
            stakingAmount: amountInPlank,
            stakingOption: stakingOption,
            chainAsset: state.chainAsset,
            selectedAccount: selectedAccount.chainAccount,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            extrinsicFeeProxy: ExtrinsicFeeProxy(),
            extrinsicSubmitMonitor: extrinsicMonitorFactory,
            restrictionsBuilder: restrictionsBuilder,
            extrinsicSubmissionProxy: extrinsicProxy,
            signingWrapper: signer,
            sharedOperation: state.sharedOperation,
            currencyManager: currencyManager
        )
    }

    private static func createRestrictionsBuilder(
        for stakingOption: SelectedStakingOption,
        state: RelaychainStartStakingStateProtocol
    ) -> RelaychainStakingRestrictionsBuilding? {
        let factory = StakingRecommendationMediatorFactory(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )

        switch stakingOption {
        case .direct:
            return factory.createDirectStakingRestrictionsBuilder(for: state)
        case .pool:
            return factory.createPoolStakingRestrictionsBuilder(for: state)
        }
    }
}
