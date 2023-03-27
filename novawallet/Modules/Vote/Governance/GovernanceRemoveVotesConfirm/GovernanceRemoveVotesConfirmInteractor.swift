import Foundation
import BigInt
import RobinHood

final class GovernanceRemoveVotesConfirmInteractor: AnyProviderAutoCleaning {
    weak var presenter: GovernanceRemoveVotesConfirmInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let signer: SigningWrapperProtocol

    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        signer: SigningWrapperProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.subscriptionFactory = subscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.extrinsicFactory = extrinsicFactory
        self.signer = signer
        self.currencyManager = currencyManager
    }

    deinit {
        clearAccounVotesSubscription()
    }

    private func clearAndSubscribeBalance() {
        clear(streamableProvider: &assetBalanceProvider)

        guard let assetId = chain.utilityAsset()?.assetId else {
            return
        }

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chain.chainId,
            assetId: assetId
        )
    }

    private func clearAndSubscribePrice() {
        priceProvider?.removeObserver(self)
        priceProvider = nil

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func clearAccounVotesSubscription() {
        subscriptionFactory.unsubscribeFromAccountVotes(self, accountId: selectedAccount.accountId)
    }

    private func subscribeAccountVotes() {
        clearAccounVotesSubscription()

        subscriptionFactory.subscribeToAccountVotes(
            self,
            accountId: selectedAccount.accountId
        ) { [weak self] result in
            switch result {
            case let .success(votingResult):
                self?.presenter?.didReceiveVotingResult(votingResult)
            case let .failure(error):
                self?.presenter?.didReceiveError(
                    GovernanceRemoveVotesInteractorError.votesSubsctiptionFailed(error)
                )
            case .none:
                break
            }
        }
    }

    private func createExtrinsicBuilderClosure(
        for requests: [GovernanceRemoveVoteRequest]
    ) -> ExtrinsicBuilderClosure {
        let actions = requests.map { request in
            GovernanceUnlockSchedule.Action.unvote(
                track: request.trackId,
                index: request.referendumId
            )
        }

        return { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.unlock(
                with: Set(actions),
                accountId: strongSelf.selectedAccount.accountId,
                builder: builder
            )
        }
    }
}

extension GovernanceRemoveVotesConfirmInteractor: GovernanceRemoveVotesConfirmInteractorInputProtocol {
    func setup() {
        clearAndSubscribeBalance()
        subscribeAccountVotes()
        clearAndSubscribePrice()
    }

    func estimateFee(for requests: [GovernanceRemoveVoteRequest]) {
        let closure = createExtrinsicBuilderClosure(for: requests)

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] feeResult in
            switch feeResult {
            case let .success(info):
                if let fee = BigUInt(info.fee) {
                    self?.presenter?.didReceiveFee(fee)
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(.feeFetchFailed(error))
            }
        }
    }

    func submit(requests: [GovernanceRemoveVoteRequest]) {
        let closure = createExtrinsicBuilderClosure(for: requests)

        extrinsicService.submit(closure, signer: signer, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(hash):
                self?.presenter?.didReceiveRemoveVotesHash(hash)
            case let .failure(error):
                self?.presenter?.didReceiveError(.removeVotesFailed(error))
            }
        }
    }

    func remakeSubscriptions() {
        clearAndSubscribeBalance()
        subscribeAccountVotes()
        clearAndSubscribePrice()
    }
}

extension GovernanceRemoveVotesConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveBalance(changes)
        case let .failure(error):
            presenter?.didReceiveError(.balanceSubscriptionFailed(error))
        }
    }
}

extension GovernanceRemoveVotesConfirmInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceivePrice(price)
        case let .failure(error):
            presenter?.didReceiveError(.priceSubscriptionFailed(error))
        }
    }
}

extension GovernanceRemoveVotesConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        clearAndSubscribePrice()
    }
}
