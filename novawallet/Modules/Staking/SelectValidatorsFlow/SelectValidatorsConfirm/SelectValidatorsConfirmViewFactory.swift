import Foundation
import Keystore_iOS
import Foundation_iOS
import Operation_iOS
import SubstrateSdk

final class SelectValidatorsConfirmViewFactory {
    static func createInitiatedBondingView(
        for state: PreparedNomination<InitiatedBonding>,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        let chainAsset = stakingState.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let metaAccountResponse = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
            let currencyManager = CurrencyManager.shared,
            let interactor = createInitiatedBondingInteractor(
                state,
                selectedMetaAccount: metaAccountResponse,
                stakingState: stakingState,
                keystore: keystore
            ) else {
            return nil
        }

        let wireframe = SelectValidatorsConfirmWireframe()

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingStartTitle()
        }

        return createView(
            for: interactor,
            wireframe: wireframe,
            stakingState: stakingState,
            title: title,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
    }

    static func createChangeTargetsView(
        for state: PreparedNomination<ExistingBonding>,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe, stakingState: stakingState)
    }

    static func createChangeYourValidatorsView(
        for state: PreparedNomination<ExistingBonding>,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe, stakingState: stakingState)
    }

    private static func createExistingBondingView(
        for state: PreparedNomination<ExistingBonding>,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        stakingState: RelaychainStakingSharedStateProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        guard let currencyManager = CurrencyManager.shared,
              let interactor = createChangeTargetsInteractor(
                  state,
                  state: stakingState,
                  keystore: keystore
              ) else {
            return nil
        }

        let title = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingChangeValidators()
        }

        return createView(
            for: interactor,
            wireframe: wireframe,
            stakingState: stakingState,
            title: title,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )
    }

    private static func createView(
        for interactor: SelectValidatorsConfirmInteractorBase,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        stakingState: RelaychainStakingSharedStateProtocol,
        title: LocalizableResource<String>,
        priceAssetInfoFactory: PriceAssetInfoFactoryProtocol
    ) -> SelectValidatorsConfirmViewProtocol? {
        let chainAsset = stakingState.stakingOption.chainAsset

        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let dataValidatingFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = SelectValidatorsConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            confirmationViewModelFactory: confirmViewModelFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            dataValidatingFactory: dataValidatingFactory,
            assetInfo: assetInfo,
            chain: chainAsset.chain,
            localizationManager: LocalizationManager.shared,
            logger: Logger.shared
        )

        let view = SelectValidatorsConfirmViewController(
            presenter: presenter,
            localizableTitle: title,
            quantityFormatter: .quantity,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter
        dataValidatingFactory.view = view

        return view
    }

    private static func createInitiatedBondingInteractor(
        _ nomination: PreparedNomination<InitiatedBonding>,
        selectedMetaAccount: MetaChainAccountResponse,
        stakingState: RelaychainStakingSharedStateProtocol,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        let chainAsset = stakingState.stakingOption.chainAsset

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let selectedAccount = try? selectedMetaAccount.toWalletDisplayAddress(),
            let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let stakingDurationFactory = stakingState.createStakingDurationOperationFactory()

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedMetaAccount.chainAccount, chain: chainAsset.chain)

        let signer = SigningWrapperFactory(keystore: keystore).createSigningWrapper(
            for: selectedMetaAccount.metaId,
            accountResponse: selectedMetaAccount.chainAccount
        )

        return InitiatedBondingConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingState.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: stakingDurationFactory,
            operationManager: operationManager,
            signer: signer,
            nomination: nomination,
            currencyManager: currencyManager
        )
    }

    private static func createChangeTargetsInteractor(
        _ nomination: PreparedNomination<ExistingBonding>,
        state: RelaychainStakingSharedStateProtocol,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        let chainAsset = state.stakingOption.chainAsset

        guard
            let currencyManager = CurrencyManager.shared,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let stakingDurationFactory = state.createStakingDurationOperationFactory()

        let extrinsicSender = nomination.bonding.controllerAccount

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: extrinsicSender.chainAccount, chain: chainAsset.chain)

        let signer = SigningWrapperFactory(keystore: keystore).createSigningWrapper(
            for: extrinsicSender.metaId,
            accountResponse: extrinsicSender.chainAccount
        )

        let accountRepository = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        return ChangeTargetsConfirmInteractor(
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.localSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: stakingDurationFactory,
            operationManager: operationManager,
            signer: signer,
            accountRepositoryFactory: accountRepository,
            nomination: nomination,
            currencyManager: currencyManager
        )
    }
}
