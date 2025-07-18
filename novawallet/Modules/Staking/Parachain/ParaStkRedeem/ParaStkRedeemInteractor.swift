import UIKit
import SubstrateSdk
import Operation_iOS

final class ParaStkRedeemInteractor {
    weak var presenter: ParaStkRedeemInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let signer: SigningWrapperProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var roundProvider: AnyDataProvider<ParachainStaking.DecodedRoundInfo>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?

    private(set) var extrinsicSubscriptionId: UInt16?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signer: SigningWrapperProtocol,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.signer = signer
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.currencyManager = currencyManager
    }

    deinit {
        cancelExtrinsicSubscriptionIfNeeded()
    }

    private func cancelExtrinsicSubscriptionIfNeeded() {
        if let extrinsicSubscriptionId = extrinsicSubscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: extrinsicSubscriptionId)
            self.extrinsicSubscriptionId = nil
        }
    }
}

extension ParaStkRedeemInteractor: ParaStkRedeemInteractorInputProtocol {
    func setup() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }

        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )

        scheduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )

        roundProvider = subscribeToRound(for: chainAsset.chain.chainId)

        feeProxy.delegate = self
    }

    private func prepareCalls(for collatorIds: Set<AccountId>) -> [ParachainStaking.ExecuteDelegatorRequest] {
        let delegator = selectedAccount.chainAccount.accountId

        return collatorIds.map { collator in
            ParachainStaking.ExecuteDelegatorRequest(delegator: delegator, candidate: collator)
        }
    }

    private func prepareExtrisicBuilderClosure(for collatorIds: Set<AccountId>) -> ExtrinsicBuilderClosure {
        let calls = prepareCalls(for: collatorIds)

        return { builder in
            var newBuilder = builder

            for call in calls {
                newBuilder = try newBuilder.adding(call: call.runtimeCall)
            }

            return newBuilder
        }
    }

    func estimateFee(for collatorIds: Set<AccountId>) {
        do {
            let compoundId = Array(collatorIds).sorted(
                by: { $0.lexicographicallyPrecedes($1) }
            ).joined()

            let extrinsicId = try Data(compoundId).blake2b16().toHex()

            let extrinsicBuilderClosure = prepareExtrisicBuilderClosure(for: collatorIds)

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: extrinsicId,
                setupBy: extrinsicBuilderClosure
            )

        } catch {
            presenter?.didReceiveFee(.failure(error))
        }
    }

    func submit(for collatorIds: Set<AccountId>) {
        let builderClosure = prepareExtrisicBuilderClosure(for: collatorIds)

        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure = { [weak self] subscriptionId in
            self?.extrinsicSubscriptionId = subscriptionId

            return self != nil
        }

        let notificationClosure: ExtrinsicSubscriptionStatusClosure = { [weak self] result in
            switch result {
            case let .success(updateModel):
                if case .inBlock = updateModel.statusUpdate.extrinsicStatus {
                    self?.cancelExtrinsicSubscriptionIfNeeded()
                    self?.presenter?.didCompleteExtrinsicSubmission(
                        for: .success(updateModel.extrinsicSubmittedModel)
                    )
                }
            case let .failure(error):
                self?.cancelExtrinsicSubscriptionIfNeeded()
                self?.presenter?.didCompleteExtrinsicSubmission(for: .failure(error))
            }
        }

        extrinsicService.submitAndWatch(
            builderClosure,
            signer: signer,
            runningIn: .main,
            subscriptionIdClosure: subscriptionIdClosure,
            notificationClosure: notificationClosure
        )
    }
}

extension ParaStkRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            presenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkRedeemInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result)
    }
}

extension ParaStkRedeemInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingScheduledRequests(
        result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>,
        for _: ChainModel.Id,
        delegatorId _: AccountId
    ) {
        switch result {
        case let .success(scheduledRequests):
            presenter?.didReceiveScheduledRequests(scheduledRequests)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }

    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(delegator):
            presenter?.didReceiveDelegator(delegator)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }

    func handleParastakingRound(
        result: Result<ParachainStaking.RoundInfo?, Error>,
        for _: ChainModel.Id
    ) {
        switch result {
        case let .success(roundInfo):
            presenter?.didReceiveRoundInfo(roundInfo)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkRedeemInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
