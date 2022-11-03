import UIKit
import SubstrateSdk
import RobinHood

final class ReferendumVoteConfirmInteractor: ReferendumVoteInteractor {
    var presenter: ReferendumVoteConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? ReferendumVoteConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?

    init(
        referendumIndex: ReferendumIdLocal,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer

        super.init(
            referendumIndex: referendumIndex,
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
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
    func submit(vote: ReferendumVoteAction) {
        let closure: ExtrinsicBuilderClosure = { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.vote(
                vote,
                referendum: strongSelf.referendumIndex,
                builder: builder
            )
        }

        extrinsicService.submit(closure, signer: signer, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(hash):
                self?.presenter?.didReceiveVotingHash(hash)
            case let .failure(error):
                self?.presenter?.didReceiveError(.submitVoteFailed(error))
            }
        }
    }
}
