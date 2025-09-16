import Foundation
import Foundation_iOS
import Keystore_iOS
import SubstrateSdk
import Operation_iOS

final class StakingPayoutConfirmationViewFactory {
    static func createView(
        for state: RelaychainStakingSharedStateProtocol,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationViewProtocol? {
        let chainAsset = state.stakingOption.chainAsset

        guard let currencyManager = CurrencyManager.shared else {
            return nil
        }

        let keystore = Keychain()

        let assetInfo = chainAsset.assetDisplayInfo
        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let payoutConfirmViewModelFactory = StakingPayoutConfirmViewModelFactory()

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
            chain: chainAsset.chain,
            localizationManager: LocalizationManager.shared,
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
        state: RelaychainStakingSharedStateProtocol,
        keystore: KeystoreProtocol,
        payouts: [PayoutInfo]
    ) -> StakingPayoutConfirmationInteractor? {
        let chainAsset = state.stakingOption.chainAsset

        guard
            let metaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = metaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            ) else {
            return nil
        }

        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId),
            let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let extrinsicServiceFactory = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeService,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        )

        let extrinsicService = extrinsicServiceFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        let signer = SigningWrapperFactory(keystore: keystore).createSigningWrapper(
            for: metaAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return StakingPayoutConfirmationInteractor(
            selectedAccount: selectedAccount,
            chainAsset: chainAsset,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            runtimeService: runtimeService,
            feeProxy: MultiExtrinsicFeeProxy(),
            chainRegistry: chainRegistry,
            signer: signer,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            payouts: payouts,
            currencyManager: currencyManager
        )
    }
}
