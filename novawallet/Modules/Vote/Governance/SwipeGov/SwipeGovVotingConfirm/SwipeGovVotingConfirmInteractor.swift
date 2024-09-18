import Foundation
import SoraFoundation
import SubstrateSdk
import Operation_iOS

final class SwipeGovVotingConfirmInteractor: ReferendumVoteInteractor {
    var presenter: SwipeGovVotingConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? SwipeGovVotingConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?
    
    private let observableState: ReferendumsObservableState
    
    private var votingItemsIds: Set<ReferendumIdLocal>
    
    
    init(
        observableState: ReferendumsObservableState,
        referendumIndexes: [ReferendumIdLocal],
        votingItemsIds: Set<ReferendumIdLocal>,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.observableState = observableState
        self.votingItemsIds = votingItemsIds
        self.signer = signer

        super.init(
            referendumIndexes: referendumIndexes,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
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
            operationQueue: operationQueue
        )
    }
    
    override func setup() {
        super.setup()
        
        observableState.addObserver(with: self) {[weak self] _, newState in
            self?.processNewState(newState.value)
        }
    }
    
    private func processNewState(_ newState: ReferendumsState) {
        guard let votedReferendumsIds = newState.voting?.value?.votes.votes.keys else {
            return
        }
        
        votedReferendumsIds.forEach { index in
            votingItemsIds.remove(index)
        }
        
        if votingItemsIds.isEmpty {
            presenter?.didReceiveSuccessBatchVoting()
        }
    }
}

extension SwipeGovVotingConfirmInteractor: SwipeGovVotingConfirmInteractorInputProtocol {
    func submit(votes: [ReferendumNewVote]) {
        let splitter = createExtrinsicSplitter(for: votes)

        extrinsicService.submitWithTxSplitter(
            splitter,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            if let error = result.errors().first {
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            } else {
                let result = result.results.compactMap({ try? $0.result.get() }).joined()
                self?.presenter?.didReceiveVotingHash(result)
            }
        }
    }
}
