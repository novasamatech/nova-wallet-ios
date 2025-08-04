import UIKit
import SubstrateSdk
import Operation_iOS
import BigInt

final class ParaStkStakeConfirmInteractor: RuntimeConstantFetching {
    weak var presenter: ParaStkStakeConfirmInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let selectedCollator: DisplayAddress
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let stakingDurationFactory: ParaStkDurationOperationFactoryProtocol
    let blockEstimationService: BlockTimeEstimationServiceProtocol
    let sharedOperation: SharedOperationProtocol?
    let signer: SigningWrapperProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var collatorProvider: AnyDataProvider<ParachainStaking.DecodedCandidateMetadata>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private(set) var extrinsicSubscriptionId: UInt16?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        selectedCollator: DisplayAddress,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signer: SigningWrapperProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: ParaStkDurationOperationFactoryProtocol,
        blockEstimationService: BlockTimeEstimationServiceProtocol,
        sharedOperation: SharedOperationProtocol?,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.selectedCollator = selectedCollator
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.signer = signer
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.stakingDurationFactory = stakingDurationFactory
        self.blockEstimationService = blockEstimationService
        self.sharedOperation = sharedOperation
        self.currencyManager = currencyManager
    }

    deinit {
        cancelExtrinsicSubscriptionIfNeeded()
    }

    private func subscribeAccountBalance() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func subscribePriceIfNeeded() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            presenter?.didReceivePrice(nil)
        }
    }

    private func subscribeDelegator() {
        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeScheduledRequests() {
        scheduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeCollatorMetadata() {
        guard let collatorId = try? selectedCollator.address.toAccountId() else {
            presenter?.didReceiveError(CommonError.dataCorruption)
            return
        }

        collatorProvider = subscribeToCandidateMetadata(
            for: chainAsset.chain.chainId,
            accountId: collatorId
        )
    }

    private func provideMinTechStake() {
        fetchConstant(
            oneOfPaths: [ParachainStaking.minDelegatorStk, ParachainStaking.minDelegation],
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(minStake):
                self?.presenter?.didReceiveMinTechStake(minStake)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func provideMinDelegationAmount() {
        fetchConstant(
            for: ParachainStaking.minDelegation,
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(minDelegation):
                self?.presenter?.didReceiveMinDelegationAmount(minDelegation)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func provideMaxDelegationsPerDelegator() {
        fetchConstant(
            for: ParachainStaking.maxDelegations,
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<UInt32, Error>) in
            switch result {
            case let .success(maxDelegations):
                self?.presenter?.didReceiveMaxDelegations(maxDelegations)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func provideStakingDuration() {
        let wrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeProvider,
            connection: connection,
            blockTimeEstimationService: blockEstimationService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let duration = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveStakingDuration(duration)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func cancelExtrinsicSubscriptionIfNeeded() {
        if let extrinsicSubscriptionId = extrinsicSubscriptionId {
            extrinsicService.cancelExtrinsicWatch(for: extrinsicSubscriptionId)
            self.extrinsicSubscriptionId = nil
        }
    }

    private func doConfirmExtrinsic(
        with callWrapper: DelegationCallWrapper,
        codingFactory: RuntimeCoderFactoryProtocol
    ) {
        let builderClosure: (ExtrinsicBuilderProtocol) throws -> ExtrinsicBuilderProtocol = { builder in
            try callWrapper.accept(builder: builder, codingFactory: codingFactory)
        }

        let subscriptionIdClosure: ExtrinsicSubscriptionIdClosure = { [weak self] subscriptionId in
            self?.extrinsicSubscriptionId = subscriptionId

            return self != nil
        }

        sharedOperation?.markSent()

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
                self?.sharedOperation?.markComposing()
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

extension ParaStkStakeConfirmInteractor: ParaStkStakeConfirmInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        subscribeAccountBalance()
        subscribePriceIfNeeded()
        subscribeDelegator()
        subscribeCollatorMetadata()
        subscribeScheduledRequests()

        provideMinTechStake()
        provideMinDelegationAmount()
        provideMaxDelegationsPerDelegator()
        provideStakingDuration()
    }

    func estimateFee(with callWrapper: DelegationCallWrapper) {
        let identifier = callWrapper.extrinsicId()

        runtimeProvider.fetchCoderFactory(
            runningIn: OperationManager(operationQueue: operationQueue),
            completion: { [weak self] codingFactory in
                guard let self else {
                    return
                }

                feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: identifier) { builder in
                    try callWrapper.accept(builder: builder, codingFactory: codingFactory)
                }
            },
            errorClosure: { [weak self] error in
                self?.presenter?.didReceiveError(error)
            }
        )
    }

    func confirm(with callWrapper: DelegationCallWrapper) {
        runtimeProvider.fetchCoderFactory(
            runningIn: OperationManager(operationQueue: operationQueue),
            completion: { [weak self] codingFactory in
                self?.doConfirmExtrinsic(with: callWrapper, codingFactory: codingFactory)
            },
            errorClosure: { [weak self] error in
                self?.presenter?.didCompleteExtrinsicSubmission(for: .failure(error))
            }
        )
    }
}

extension ParaStkStakeConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension ParaStkStakeConfirmInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkStakeConfirmInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
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

    func handleParastakingCandidateMetadata(
        result: Result<ParachainStaking.CandidateMetadata?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(metadata):
            presenter?.didReceiveCollator(metadata: metadata)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }

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

extension ParaStkStakeConfirmInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result)
    }
}

extension ParaStkStakeConfirmInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
