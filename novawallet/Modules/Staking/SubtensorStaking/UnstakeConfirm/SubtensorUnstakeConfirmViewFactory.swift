import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS
import BigInt

enum SubtensorUnstakeConfirmViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        position: SubtensorStakePosition,
        amount: Decimal
    ) -> SubtensorStakingConfirmViewProtocol? {
        guard
            let selectedMetaAccount = SelectedWalletSettings.shared.value,
            let currencyManager = CurrencyManager.shared,
            let selectedAccount = selectedMetaAccount.fetchMetaChainAccount(
                for: chainAsset.chain.accountRequest()
            )
        else {
            return nil
        }

        guard let interactor = createInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            position: position,
            amount: amount,
            currencyManager: currencyManager
        ) else {
            return nil
        }

        let wireframe = SubtensorUnstakeConfirmWireframe()
        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        // This screen is alpha-denominated (chainAsset is the subnet token), but the
        // Nova fee is charged in TAO (0.3% of the TAO received). Render it with a TAO
        // factory so the row shows "TAO", not the subnet symbol.
        let novaFeeBalanceViewModelFactory: BalanceViewModelFactoryProtocol? = chainAsset
            .subtensorTaoAsset()
            .map {
                BalanceViewModelFactory(
                    targetAssetInfo: $0.assetDisplayInfo,
                    priceAssetInfoFactory: priceAssetInfoFactory
                )
            }

        let presenter = SubtensorUnstakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            novaFeeBalanceViewModelFactory: novaFeeBalanceViewModelFactory,
            position: position,
            amount: amount,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let isSubnet = position.netuid != SubtensorStakingConstants.rootNetuid
        let localizableTitle = LocalizableResource { _ in
            if isSubnet {
                return "Unstake — SN\(position.netuid)"
            }
            return "Unstake"
        }

        let localizableValidatorLabel = LocalizableResource { locale in
            R.string(preferredLanguages: locale.rLanguages).localizable.stakingSubtensorValidator()
        }

        let view = SubtensorStakingConfirmViewController(
            presenter: presenter,
            localizableTitle: localizableTitle,
            localizableCollatorLabel: localizableValidatorLabel,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        position: SubtensorStakePosition,
        amount: Decimal,
        currencyManager: CurrencyManagerProtocol
    ) -> SubtensorUnstakeConfirmInteractor? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry

        guard
            let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId),
            let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId)
        else {
            return nil
        }

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            userStorageFacade: UserDataStorageFacade.shared,
            substrateStorageFacade: SubstrateDataStorageFacade.shared
        ).createService(account: selectedAccount.chainAccount, chain: chainAsset.chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        guard let amountInPlank = amount.toSubstrateAmount(
            precision: chainAsset.assetDisplayInfo.assetPrecision
        ) else {
            return nil
        }

        return SubtensorUnstakeConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            hotkey: position.hotkey,
            netuid: position.netuid,
            amount: amountInPlank,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            extrinsicService: extrinsicService,
            feeProxy: ExtrinsicFeeProxy(),
            signer: signer,
            callFactory: SubstrateCallFactory(),
            currencyManager: currencyManager,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }
}
