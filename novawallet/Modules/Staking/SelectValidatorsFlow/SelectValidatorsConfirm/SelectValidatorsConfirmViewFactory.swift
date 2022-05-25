import Foundation
import SoraKeystore
import SoraFoundation
import RobinHood
import SubstrateSdk

final class SelectValidatorsConfirmViewFactory {
    static func createInitiatedBondingView(
        for state: PreparedNomination<InitiatedBonding>,
        stakingState: StakingSharedState
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let chainAsset = stakingState.settings.value,
            let metaAccountResponse = metaAccount.fetchMetaChainAccount(for: chainAsset.chain.accountRequest()),
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
            R.string.localizable.stakingStartTitle(preferredLanguages: locale.rLanguages)
        }

        return createView(
            for: interactor,
            wireframe: wireframe,
            stakingState: stakingState,
            title: title
        )
    }

    static func createChangeTargetsView(
        for state: PreparedNomination<ExistingBonding>,
        stakingState: StakingSharedState
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe, stakingState: stakingState)
    }

    static func createChangeYourValidatorsView(
        for state: PreparedNomination<ExistingBonding>,
        stakingState: StakingSharedState
    ) -> SelectValidatorsConfirmViewProtocol? {
        let wireframe = YourValidatorList.SelectValidatorsConfirmWireframe()
        return createExistingBondingView(for: state, wireframe: wireframe, stakingState: stakingState)
    }

    private static func createExistingBondingView(
        for state: PreparedNomination<ExistingBonding>,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        stakingState: StakingSharedState
    ) -> SelectValidatorsConfirmViewProtocol? {
        let keystore = Keychain()

        guard let interactor = createChangeTargetsInteractor(
            state,
            state: stakingState,
            keystore: keystore
        ) else {
            return nil
        }

        let title = LocalizableResource { locale in
            R.string.localizable.stakingChangeValidators(preferredLanguages: locale.rLanguages)
        }

        return createView(
            for: interactor,
            wireframe: wireframe,
            stakingState: stakingState,
            title: title
        )
    }

    private static func createView(
        for interactor: SelectValidatorsConfirmInteractorBase,
        wireframe: SelectValidatorsConfirmWireframeProtocol,
        stakingState: StakingSharedState,
        title: LocalizableResource<String>
    ) -> SelectValidatorsConfirmViewProtocol? {
        guard let chainAsset = stakingState.settings.value else {
            return nil
        }

        let confirmViewModelFactory = SelectValidatorsConfirmViewModelFactory()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

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
            explorers: chainAsset.chain.explorers,
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
        stakingState: StakingSharedState,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        guard
            let chainAsset = stakingState.settings.value,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let selectedAccount = try? selectedMetaAccount.toWalletDisplayAddress() else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedMetaAccount.chainAccount.accountId,
            chain: chainAsset.chain,
            cryptoType: selectedMetaAccount.chainAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            metaId: selectedMetaAccount.metaId,
            accountResponse: selectedMetaAccount.chainAccount
        )

        return InitiatedBondingConfirmInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: stakingState.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            nomination: nomination
        )
    }

    private static func createChangeTargetsInteractor(
        _ nomination: PreparedNomination<ExistingBonding>,
        state: StakingSharedState,
        keystore: KeystoreProtocol
    ) -> SelectValidatorsConfirmInteractorBase? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        let operationManager = OperationManagerFacade.sharedManager

        guard
            let chainAsset = state.settings.value,
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let extrinsicSender = nomination.bonding.controllerAccount

        let extrinsicService = ExtrinsicService(
            accountId: extrinsicSender.chainAccount.accountId,
            chain: chainAsset.chain,
            cryptoType: extrinsicSender.chainAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let signer = SigningWrapper(
            keystore: keystore,
            metaId: extrinsicSender.metaId,
            accountResponse: extrinsicSender.chainAccount
        )

        let accountRepository = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        return ChangeTargetsConfirmInteractor(
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            durationOperationFactory: StakingDurationOperationFactory(),
            operationManager: operationManager,
            signer: signer,
            accountRepositoryFactory: accountRepository,
            nomination: nomination
        )
    }
}
