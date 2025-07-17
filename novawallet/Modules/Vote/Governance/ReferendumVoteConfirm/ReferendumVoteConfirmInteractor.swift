import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumVoteConfirmInteractor: ReferendumObservingVoteInteractor {
    var presenter: ReferendumVoteConfirmInteractorOutputProtocol? {
        get { basePresenter as? ReferendumVoteConfirmInteractorOutputProtocol }
        set { basePresenter = newValue }
    }

    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?

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
        signer: SigningWrapperProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        chainRegistry: ChainRegistryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer

        super.init(
            observableState: observableState,
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

    private func clearAndSubscribeLocks() {
        locksSubscription?.removeObserver(self)
        locksSubscription = nil

        guard let asset = chain.utilityAsset() else {
            return
        }

        locksSubscription = subscribeToLocksProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    override func setup() {
        super.setup()

        clearAndSubscribeLocks()
    }

    override func remakeSubscriptions() {
        super.remakeSubscriptions()

        clearAndSubscribeLocks()
    }

    override func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            let locks = changes.mergeToDict([:]).values
            presenter?.didReceiveLocks(Array(locks))
        case let .failure(error):
            presenter?.didReceiveError(.locksSubscriptionFailed(error))
        }
    }
}

// MARK: ReferendumVoteConfirmInteractorInputProtocol

extension ReferendumVoteConfirmInteractor: ReferendumVoteConfirmInteractorInputProtocol {
    func submit(vote: ReferendumNewVote) {
        let splitter = createExtrinsicSplitter(for: [vote])

        extrinsicService.submitWithTxSplitter(
            splitter,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            if let error = result.errors().first {
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            } else {
                guard let sender = result.senders().first else {
                    return
                }

                self?.presenter?.didReceiveVotingCompletion(sender)
            }
        }
    }
}
