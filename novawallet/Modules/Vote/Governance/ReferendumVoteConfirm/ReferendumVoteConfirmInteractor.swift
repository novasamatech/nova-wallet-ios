import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumVoteConfirmInteractor: ReferendumVoteInteractor {
    var presenter: BaseReferendumVoteConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? BaseReferendumVoteConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?

    init(
        referendumIndexes: [ReferendumIdLocal],
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

extension ReferendumVoteConfirmInteractor: ReferendumVoteConfirmInteractorInputProtocol {
    func submit(vote: ReferendumNewVote) {
        let splitter = createExtrinsicSplitter(for: [vote])

        extrinsicService.submitWithTxSplitter(
            splitter,
            signer: signer,
            runningIn: .main
        ) { [weak self] result in
            if let result = result.results.compactMap({ try? $0.result.get() }).first {
                self?.presenter?.didReceiveVotingHash(result)
            } else if let error = result.errors().first {
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            }
        }
    }
}
