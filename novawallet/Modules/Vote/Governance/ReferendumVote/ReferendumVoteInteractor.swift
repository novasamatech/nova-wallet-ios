import Foundation
import RobinHood
import BigInt

class ReferendumVoteInteractor {
    private weak var basePresenter: ReferendumVoteInteractorOutputProtocol?

    let referendumIndex: ReferendumIdLocal
    let selectedAccount: MetaChainAccountResponse
    let chain: ChainModel
    let referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?

    init(
        referendumIndex: ReferendumIdLocal,
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.referendumIndex = referendumIndex
        self.selectedAccount = selectedAccount
        self.chain = chain
        self.referendumsSubscriptionFactory = referendumsSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicFactory = extrinsicFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.currencyManager = currencyManager
    }

    deinit {
        clearReferendumSubscriptions()
    }

    private func clearReferendumSubscriptions() {
        referendumsSubscriptionFactory.unsubscribeFromReferendum(self, referendumIndex: referendumIndex)
    }

    private func subscribeBalanceIfNeeded() {
        assetBalanceProvider?.removeObserver(self)
        assetBalanceProvider = nil

        if let asset = chain.utilityAsset() {
            assetBalanceProvider = subscribeToAssetBalanceProvider(
                for: selectedAccount.chainAccount.accountId,
                chainId: chain.chainId,
                assetId: asset.assetId
            )
        }
    }

    private func subscribePriceIfNeeded() {
        priceProvider?.removeObserver(self)
        priceProvider = nil

        if let priceId = chain.utilityAsset()?.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func subscribeReferendum() {
        referendumsSubscriptionFactory.subscribeToReferendum(self, referendumIndex: referendumIndex) { [weak self] result in
            switch result {
            case let .success(storageResult):
                if let referendum = storageResult.value {
                    self?.basePresenter?.didReceiveVotingReferendum(referendum)
                }
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.votingReferendumFailed(error))
            case .none:
                break
            }
        }
    }

    private func makeSubscriptions() {
        subscribeBalanceIfNeeded()
        subscribePriceIfNeeded()

        clearReferendumSubscriptions()
        subscribeReferendum()
    }

    func setup() {
        feeProxy.delegate = self

        makeSubscriptions()
    }

    func remakeSubscriptions() {
        makeSubscriptions()
    }
}

extension ReferendumVoteInteractor: ReferendumVoteInteractorInputProtocol {
    func estimateFee(for vote: ReferendumVoteAction) {
        let reuseIdentifier = "\(vote.hashValue)"

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: reuseIdentifier) { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.vote(
                vote,
                referendum: strongSelf.referendumIndex,
                builder: builder
            )
        }
    }
}

extension ReferendumVoteInteractor: WalletLocalSubscriptionHandler, WalletLocalStorageSubscriber {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.assetBalanceFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            basePresenter?.didReceivePrice(price)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.priceFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        switch result {
        case let .success(dispatchInfo):
            if let fee = BigUInt(dispatchInfo.fee) {
                basePresenter?.didReceiveFee(fee)
            }
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.feeFailed(error))
        }
    }
}

extension ReferendumVoteInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        subscribePriceIfNeeded()
    }
}
