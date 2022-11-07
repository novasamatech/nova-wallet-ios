import Foundation
import RobinHood
import SubstrateSdk
import SoraFoundation

struct ReferendumVoteConfirmViewFactory {
    static func createView(
        for state: GovernanceSharedState,
        newVote: ReferendumNewVote
    ) -> ReferendumVoteConfirmViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let interactor = createInteractor(
                for: state,
                referendum: newVote.index,
                currencyManager: currencyManager
            ),
            let chain = state.settings.value,
            let assetDisplayInfo = chain.utilityAsset()?.displayInfo(with: chain.icon),
            let selectedAccount = SelectedWalletSettings.shared.value?.fetchMetaChainAccount(
                for: chain.accountRequest()
            ),
            let votingLockId = state.governanceId(for: chain)
        else {
            return nil
        }

        let wireframe = ReferendumVoteConfirmWireframe()

        let localizationManager = LocalizationManager.shared

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: assetDisplayInfo,
            priceAssetInfoFactory: PriceAssetInfoFactory(currencyManager: currencyManager)
        )

        let lockChangeViewModelFactory = ReferendumLockChangeViewModelFactory(
            assetDisplayInfo: assetDisplayInfo,
            votingLockId: votingLockId
        )

        let referendumStringsViewModelFactory = ReferendumDisplayStringFactory()

        let dataValidatingFactory = GovernanceValidatorFactory(
            presentable: wireframe,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let presenter = ReferendumVoteConfirmPresenter(
            vote: newVote,
            chain: chain,
            selectedAccount: selectedAccount,
            dataValidatingFactory: dataValidatingFactory,
            balanceViewModelFactory: balanceViewModelFactory,
            referendumFormatter: NumberFormatter.index.localizableResource(),
            referendumStringsViewModelFactory: referendumStringsViewModelFactory,
            lockChangeViewModelFactory: lockChangeViewModelFactory,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        let view = ReferendumVoteConfirmViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        dataValidatingFactory.view = view
        interactor.presenter = presenter

        return view
    }

    // swiftlint:disable:next function_body_length
    private static func createInteractor(
        for state: GovernanceSharedState,
        referendum: ReferendumIdLocal,
        currencyManager: CurrencyManagerProtocol
    ) -> ReferendumVoteConfirmInteractor? {
        let wallet: MetaAccountModel? = SelectedWalletSettings.shared.value

        guard
            let chain = state.settings.value,
            let selectedAccount = wallet?.fetchMetaChainAccount(for: chain.accountRequest()),
            let subscriptionFactory = state.subscriptionFactory,
            let lockStateFactory = state.locksOperationFactory,
            let extrinsicFactory = state.createExtrinsicFactory(for: chain),
            let blockTimeService = state.blockTimeService
        else {
            return nil
        }

        guard
            let connection = state.chainRegistry.getConnection(for: chain.chainId),
            let runtimeProvider = state.chainRegistry.getRuntimeProvider(for: chain.chainId) else {
            return nil
        }

        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let operationManager = OperationManager(operationQueue: operationQueue)

        let extrinsicService = ExtrinsicServiceFactory(
            runtimeRegistry: runtimeProvider,
            engine: connection,
            operationManager: operationManager
        ).createService(account: selectedAccount.chainAccount, chain: chain)

        let signer = SigningWrapperFactory().createSigningWrapper(
            for: selectedAccount.metaId,
            accountResponse: selectedAccount.chainAccount
        )

        return ReferendumVoteConfirmInteractor(
            referendumIndex: referendum,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: state.generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: subscriptionFactory,
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            priceLocalSubscriptionFactory: PriceProviderFactory.shared,
            blockTimeService: blockTimeService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            signer: signer,
            feeProxy: ExtrinsicFeeProxy(),
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }
}
