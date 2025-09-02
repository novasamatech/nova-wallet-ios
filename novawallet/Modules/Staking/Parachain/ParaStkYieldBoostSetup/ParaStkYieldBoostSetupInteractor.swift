import UIKit
import SubstrateSdk
import Operation_iOS
import BigInt

final class ParaStkYieldBoostSetupInteractor: AnyCancellableCleaning {
    weak var presenter: ParaStkYieldBoostSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol
    let yieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol
    let operationQueue: OperationQueue

    let childScheduleInteractor: ParaStkYieldBoostScheduleInteractorInputProtocol
    let childCancelInteractor: ParaStkYieldBoostCancelInteractorInputProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var yieldBoostProvider: AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?
    private var yieldBoostParamsCancellable: CancellableCall?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        childScheduleInteractor: ParaStkYieldBoostScheduleInteractorInputProtocol,
        childCancelInteractor: ParaStkYieldBoostCancelInteractorInputProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol,
        yieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.childScheduleInteractor = childScheduleInteractor
        self.childCancelInteractor = childCancelInteractor
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.rewardService = rewardService
        self.connection = connection
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.identityProxyFactory = identityProxyFactory
        self.yieldBoostProviderFactory = yieldBoostProviderFactory
        self.yieldBoostOperationFactory = yieldBoostOperationFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        clear(cancellable: &yieldBoostParamsCancellable)
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let calculator = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveRewardCalculator(calculator)
                } catch {
                    self?.presenter?.didReceiveError(.rewardCalculatorFetchFailed)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func subscribeAssetBalanceAndPrice() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func subscribeDelegator() {
        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.accountId
        )
    }

    private func subscribeScheduledRequests() {
        scheduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.accountId
        )
    }

    private func subscribeYieldBoostTasks() {
        yieldBoostProvider = subscribeYieldBoostTasks(
            for: chainAsset.chainAssetId,
            accountId: selectedAccount.accountId
        )
    }

    private func provideIdentities(for delegations: [AccountId]) {
        let wrapper = identityProxyFactory.createIdentityWrapper(for: { delegations })

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let identities = try wrapper.targetOperation.extractNoCancellableResultData()
                    let identitiesByAccountId = try identities.reduce(
                        into: [AccountId: AccountIdentity]()
                    ) { result, keyValue in
                        let accountId = try keyValue.key.toAccountId()
                        result[accountId] = keyValue.value
                    }

                    self?.presenter?.didReceiveDelegationIdentities(identitiesByAccountId)
                } catch {
                    self?.presenter?.didReceiveError(.identitiesFetchFailed)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    private func setupSubscriptions() {
        subscribeAssetBalanceAndPrice()
        subscribeDelegator()
        subscribeScheduledRequests()
        subscribeYieldBoostTasks()
    }
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostSetupInteractorInputProtocol {
    func setup() {
        childScheduleInteractor.setup()
        childCancelInteractor.setup()

        setupSubscriptions()
        provideRewardCalculator()
    }

    func retrySubscriptions() {
        setupSubscriptions()
    }

    func fetchIdentities(for collators: [AccountId]) {
        provideIdentities(for: collators)
    }

    func fetchRewardCalculator() {
        provideRewardCalculator()
    }

    func requestParams(for stake: BigUInt, collator: AccountId) {
        clear(cancellable: &yieldBoostParamsCancellable)

        guard
            let amountToStake = Decimal(stake),
            let collatorAddress = try? collator.toAddress(using: chainAsset.chain.chainFormat) else {
            presenter?.didReceiveError(
                .yieldBoostParamsFailed(CommonError.dataCorruption, stake: stake, collator: collator)
            )
            return
        }

        let wrapper = yieldBoostOperationFactory.createAutocompoundParamsOperation(
            for: connection,
            request: ParaStkYieldBoostRequest(amountToStake: amountToStake, collator: collatorAddress)
        )

        yieldBoostParamsCancellable = wrapper

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.yieldBoostParamsCancellable === wrapper else {
                    return
                }

                self?.yieldBoostParamsCancellable = nil

                do {
                    let response = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveYieldBoostParams(response, stake: stake, collator: collator)
                } catch {
                    self?.presenter?.didReceiveError(
                        .yieldBoostParamsFailed(error, stake: stake, collator: collator)
                    )
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostScheduleInteractorInputProtocol {
    func estimateScheduleAutocompoundFee(
        for collatorId: AccountId,
        initTime: AutomationTime.UnixTime,
        frequency: AutomationTime.Seconds,
        accountMinimum: BigUInt,
        cancellingTaskIds: Set<AutomationTime.TaskId>
    ) {
        childScheduleInteractor.estimateScheduleAutocompoundFee(
            for: collatorId,
            initTime: initTime,
            frequency: frequency,
            accountMinimum: accountMinimum,
            cancellingTaskIds: cancellingTaskIds
        )
    }

    func estimateTaskExecutionFee() {
        childScheduleInteractor.estimateTaskExecutionFee()
    }

    func fetchTaskExecutionTime(for period: UInt) {
        childScheduleInteractor.fetchTaskExecutionTime(for: period)
    }
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostCancelInteractorInputProtocol {
    func estimateCancelAutocompoundFee(for taskId: AutomationTime.TaskId) {
        childCancelInteractor.estimateCancelAutocompoundFee(for: taskId)
    }
}

extension ParaStkYieldBoostSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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
            presenter?.didReceiveError(.balanceSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(.priceSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostSetupInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(delegator):
            presenter?.didReceiveDelegator(delegator)

            if let collators = delegator?.collators() {
                provideIdentities(for: collators)
            }
        case let .failure(error):
            presenter?.didReceiveError(.delegatorSubscriptionFailed(error))
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
            presenter?.didReceiveError(.scheduledRequestsSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostStorageSubscriber, ParaStkYieldBoostSubscriptionHandler {
    func handleYieldBoostTasks(
        result: Result<[ParaStkYieldBoostState.Task]?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(tasks):
            presenter?.didReceiveYieldBoostTasks(tasks ?? [])
        case let .failure(error):
            presenter?.didReceiveError(.yieldBoostTaskSubscriptionFailed(error))
        }
    }
}

extension ParaStkYieldBoostSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
