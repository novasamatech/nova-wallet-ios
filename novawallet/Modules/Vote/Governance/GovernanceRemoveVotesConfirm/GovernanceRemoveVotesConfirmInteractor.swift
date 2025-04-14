import Foundation
import BigInt
import Operation_iOS

final class GovernanceRemoveVotesConfirmInteractor: AnyProviderAutoCleaning {
    weak var presenter: GovernanceRemoveVotesConfirmInteractorOutputProtocol?

    let selectedAccount: ChainAccountResponse
    let chain: ChainModel
    let chainRegistry: ChainRegistryProtocol
    let subscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue

    private var assetBalanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        selectedAccount: ChainAccountResponse,
        chain: ChainModel,
        chainRegistry: ChainRegistryProtocol,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        signer: SigningWrapperProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.chainRegistry = chainRegistry
        self.subscriptionFactory = subscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.extrinsicFactory = extrinsicFactory
        self.signer = signer
        self.operationQueue = operationQueue
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

    private func createExtrinsicSplitter(
        for requests: [GovernanceRemoveVoteRequest]
    ) throws -> ExtrinsicSplitting {
        let actions = requests.map { request in
            GovernanceUnlockSchedule.Action.unvote(
                track: request.trackId,
                index: request.referendumId
            )
        }

        let splitter = ExtrinsicSplitter(
            chain: chain,
            maxCallsPerExtrinsic: selectedAccount.type.maxCallsPerExtrinsic,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue
        )

        return try extrinsicFactory.unlock(
            with: Set(actions),
            accountId: selectedAccount.accountId,
            splitter: splitter
        )
    }

    func handleMultiExtrinsicSubmission(result: SubmitIndexedExtrinsicResult) {
        presenter?.didReceiveSubmissionResult(result)
    }
}

extension GovernanceRemoveVotesConfirmInteractor: GovernanceRemoveVotesConfirmInteractorInputProtocol {
    func setup() {
        clearAndSubscribeBalance()
        subscribeAccountVotes()
        clearAndSubscribePrice()
    }

    func estimateFee(for requests: [GovernanceRemoveVoteRequest]) {
        do {
            let splitter = try createExtrinsicSplitter(for: requests)

            extrinsicService.estimateFeeWithSplitter(
                splitter,
                runningIn: .main
            ) { [weak self] result in
                switch result.convertToTotalFee() {
                case let .success(fee):
                    self?.presenter?.didReceiveFee(fee)
                case let .failure(error):
                    self?.presenter?.didReceiveError(.feeFetchFailed(error))
                }
            }
        } catch {
            presenter?.didReceiveError(.feeFetchFailed(error))
        }
    }

    func submit(requests: [GovernanceRemoveVoteRequest]) {
        do {
            let splitter = try createExtrinsicSplitter(for: requests)

            extrinsicService.submitWithTxSplitter(
                splitter,
                signer: signer,
                runningIn: .main
            ) { [weak self] result in
                self?.handleMultiExtrinsicSubmission(result: result)
            }
        } catch {
            presenter?.didReceiveError(.removeVotesFailed(error))
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
