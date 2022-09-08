import UIKit
import SubstrateSdk
import RobinHood
import BigInt

final class ParaStkYieldBoostSetupInteractor: AnyCancellableCleaning {
    weak var presenter: ParaStkYieldBoostSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let identityOperationFactory: IdentityOperationFactoryProtocol
    let yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol
    let yieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var yieldBoostProvider: AnySingleValueProvider<[ParaStkYieldBoostState.Task]>?
    private var yieldBoostParamsCancellable: CancellableCall?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        identityOperationFactory: IdentityOperationFactoryProtocol,
        yieldBoostProviderFactory: ParaStkYieldBoostProviderFactoryProtocol,
        yieldBoostOperationFactory: ParaStkYieldBoostOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.rewardService = rewardService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.identityOperationFactory = identityOperationFactory
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
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.accountId
        )
    }

    private func provideIdentities(for delegations: [AccountId]) {
        let wrapper = identityOperationFactory.createIdentityWrapper(
            for: { delegations },
            engine: connection,
            runtimeService: runtimeProvider,
            chainFormat: chainAsset.chain.chainFormat
        )

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
}

extension ParaStkYieldBoostSetupInteractor: ParaStkYieldBoostSetupInteractorInputProtocol {
    func setup() {
        subscribeAssetBalanceAndPrice()
        subscribeDelegator()
        subscribeScheduledRequests()
        subscribeYieldBoostTasks()

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
