import Foundation
import Foundation_iOS
import SubstrateSdk

class ReferendumObservingVoteInteractor: ReferendumVoteInteractor {
    var output: ReferendumObservingVoteInteractorOutputProtocol? {
        get { super.basePresenter as? ReferendumObservingVoteInteractorOutputProtocol }
        set { super.basePresenter = newValue }
    }

    let observableState: ReferendumsObservableState

    init(
        observableState: ReferendumsObservableState,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )
    }

    deinit {
        observableState.removeObserver(by: self)
    }

    override func makeSubscriptions() {
        super.makeSubscriptions()

        subscribeObservableState()
    }

    private func subscribeObservableState() {
        observableState.addObserver(
            with: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, new in
            self?.output?.didReceiveVotingReferendumsState(new.value)
        }
    }
}
