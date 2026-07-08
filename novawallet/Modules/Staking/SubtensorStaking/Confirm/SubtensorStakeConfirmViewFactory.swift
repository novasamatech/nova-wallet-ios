import Foundation
import Foundation_iOS
import SubstrateSdk
import Keystore_iOS
import BigInt

enum SubtensorStakeConfirmViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        validator: SubtensorValidator,
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
            validator: validator,
            amount: amount,
            currencyManager: currencyManager
        ) else {
            return nil
        }

        let wireframe = SubtensorStakeConfirmWireframe()
        let localizationManager = LocalizationManager.shared

        let priceAssetInfoFactory = PriceAssetInfoFactory(currencyManager: currencyManager)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            priceAssetInfoFactory: priceAssetInfoFactory
        )

        let presenter = SubtensorStakeConfirmPresenter(
            interactor: interactor,
            wireframe: wireframe,
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            balanceViewModelFactory: balanceViewModelFactory,
            validator: validator,
            amount: amount,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let isSubnet = validator.netuid != SubtensorStakingConstants.rootNetuid
        let localizableTitle = LocalizableResource { locale in
            if isSubnet {
                return "Confirm — SN\(validator.netuid)"
            }
            return R.string(preferredLanguages: locale.rLanguages).localizable.commonConfirmTitle()
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
        validator: SubtensorValidator,
        amount: Decimal,
        currencyManager: CurrencyManagerProtocol
    ) -> SubtensorStakeConfirmInteractor? {
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

        return SubtensorStakeConfirmInteractor(
            chainAsset: chainAsset,
            selectedAccount: selectedAccount,
            hotkey: validator.hotkey,
            netuid: validator.netuid,
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
