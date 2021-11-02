import Foundation
import SoraFoundation
import SoraKeystore
import SubstrateSdk
import RobinHood

final class StakingPayoutConfirmationViewFactory {
    static func createView(
        for state: StakingSharedState,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationViewProtocol? {
        guard let chainAsset = state.settings.value else {
            return nil
        }

        let keystore = Keychain()

        let assetInfo = chainAsset.assetDisplayInfo
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: assetInfo)

        let payoutConfirmViewModelFactory = StakingPayoutConfirmViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let wireframe = StakingPayoutConfirmationWireframe()

        let dataValidationFactory = StakingDataValidatingFactory(
            presentable: wireframe,
            balanceFactory: balanceViewModelFactory
        )

        let presenter = StakingPayoutConfirmationPresenter(
            balanceViewModelFactory: balanceViewModelFactory,
            payoutConfirmViewModelFactory: payoutConfirmViewModelFactory,
            dataValidatingFactory: dataValidationFactory,
            assetInfo: assetInfo,
            logger: Logger.shared
        )

        let view = StakingPayoutConfirmationViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        guard let interactor = createInteractor(state: state, keystore: keystore, payouts: payouts) else {
            return nil
        }

        dataValidationFactory.view = view
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        state: StakingSharedState,
        keystore: KeystoreProtocol,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationInteractor? {
        guard
            let chainAsset = state.settings.value,
            let metaAccount = SelectedWalletSettings.shared.value,
            let selectedAccount = metaAccount.fetch(for: chainAsset.chain.accountRequest()) else {
            return nil
        }

        let operationManager = OperationManagerFacade.sharedManager
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let extrinsicService = ExtrinsicService(
            accountId: selectedAccount.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        let extrinsicOperationFactory = ExtrinsicOperationFactory(
            accountId: selectedAccount.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: selectedAccount.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection
        )

        let signer = SigningWrapper(
            keystore: keystore,
            metaId: metaAccount.metaId,
            accountResponse: selectedAccount
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        return StakingPayoutConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            stakingLocalSubscriptionFactory: state.stakingLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicOperationFactory: extrinsicOperationFactory,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            signer: signer,
            accountRepositoryFactory: accountRepositoryFactory,
            operationManager: operationManager,
            payouts: payouts
        )
    }
}
