import UIKit
import Operation_iOS
import SubstrateSdk

final class ParaStkRebondInteractor: AnyCancellableCleaning {
    weak var presenter: ParaStkRebondInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let signer: SigningWrapperProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var identityFetchCall: CancellableCall?

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
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.signer = signer
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.identityProxyFactory = identityProxyFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &identityFetchCall)

        cancelExtrinsicSubscriptionIfNeeded()
    }

    private func cancelExtrinsicSubscriptionIfNeeded() {
        if let extrinsicSubscriptionId = extrinsicSubscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: extrinsicSubscriptionId)
            self.extrinsicSubscriptionId = nil
        }
    }

    private func prepareExtrisicBuilderClosure(for collator: AccountId) -> ExtrinsicBuilderClosure {
        let call = ParachainStaking.CancelDelegatorRequest(candidate: collator)

        return { builder in
            try builder.adding(call: call.runtimeCall)
        }
    }
}

extension ParaStkRebondInteractor: ParaStkRebondInteractorInputProtocol {
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

        scheduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )

        feeProxy.delegate = self
    }

    func estimateFee(for collator: AccountId) {
        let extrinsicBuilderClosure = prepareExtrisicBuilderClosure(for: collator)

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: collator.toHex(),
            setupBy: extrinsicBuilderClosure
        )
    }

    func submit(for collator: AccountId) {
        let builderClosure = prepareExtrisicBuilderClosure(for: collator)

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

    func fetchIdentity(for collator: AccountId) {
        clear(cancellable: &identityFetchCall)

        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { [collator] })

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.identityFetchCall === wrapper else {
                    return
                }

                self?.identityFetchCall = nil

                do {
                    let identities = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveCollatorIdentity(identities[collator])
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        identityFetchCall = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkRebondInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension ParaStkRebondInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkRebondInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result)
    }
}

extension ParaStkRebondInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
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
}

extension ParaStkRebondInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
