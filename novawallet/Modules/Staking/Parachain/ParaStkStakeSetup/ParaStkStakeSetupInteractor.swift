import UIKit
import Operation_iOS
import BigInt
import SubstrateSdk

final class ParaStkStakeSetupInteractor: RuntimeConstantFetching {
    weak var presenter: ParaStkStakeSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var collatorSubscription: CallbackStorageSubscription<ParachainStaking.CandidateMetadata>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var scheduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?
    private var collatorsCancellable = CancellableCallStore()
    private var delegatorIdentityCancellable = CancellableCallStore()

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.preferredCollatorFactory = preferredCollatorFactory
        self.rewardService = rewardService
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.repositoryFactory = repositoryFactory
        self.identityProxyFactory = identityProxyFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    deinit {
        self.collatorSubscription = nil

        collatorsCancellable.cancel()
        delegatorIdentityCancellable.cancel()
    }

    private func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let calculator = try operation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveRewardCalculator(calculator)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperation(operation)
    }

    private func subscribeAssetBalanceAndPrice() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
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
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeScheduledRequests() {
        scheduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeRemoteCollator(for accountId: AccountId) {
        collatorSubscription = nil

        do {
            let storagePath = ParachainStaking.candidateMetadataPath
            let localKey = try localKeyFactory.createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let repository = repositoryFactory.createChainStorageItemRepository()

            let request = MapSubscriptionRequest(
                storagePath: ParachainStaking.candidateMetadataPath,
                localKey: localKey,
                keyParamClosure: { BytesCodable(wrappedValue: accountId) }
            )

            collatorSubscription = CallbackStorageSubscription(
                request: request,
                connection: connection,
                runtimeService: runtimeProvider,
                repository: repository,
                operationQueue: operationQueue,
                callbackQueue: .main
            ) { [weak self] result in
                switch result {
                case let .success(collator):
                    self?.presenter?.didReceiveCollator(metadata: collator)
                case let .failure(error):
                    self?.presenter?.didReceiveError(error)
                }
            }
        } catch {
            presenter?.didReceiveError(error)
        }
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

    private func provideIdentities(for delegations: [AccountId]) {
        let wrapper = identityProxyFactory.createIdentityWrapper(for: { delegations })

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: delegatorIdentityCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                do {
                    let identitiesByAccountId = try identities.reduce(
                        into: [AccountId: AccountIdentity]()
                    ) { result, keyValue in
                        let accountId = try keyValue.key.toAccountId()
                        result[accountId] = keyValue.value
                    }

                    self?.presenter?.didReceiveDelegationIdentities(identitiesByAccountId)
                } catch {
                    self?.presenter?.didReceiveError(error)
                }
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    private func providePreferredCollator() {
        guard let operationFactory = preferredCollatorFactory else {
            presenter?.didReceivePreferredCollator(nil)
            return
        }

        let wrapper = operationFactory.createPreferredCollatorWrapper()

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: collatorsCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(optCollator):
                self?.presenter?.didReceivePreferredCollator(optCollator)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }
}

extension ParaStkStakeSetupInteractor: ParaStkStakeSetupInteractorInputProtocol {
    func setup() {
        subscribeAssetBalanceAndPrice()
        subscribeDelegator()
        subscribeScheduledRequests()

        provideRewardCalculator()

        feeProxy.delegate = self

        providePreferredCollator()

        provideMinTechStake()
        provideMinDelegationAmount()
        provideMaxDelegationsPerDelegator()
    }

    func applyCollator(with accountId: AccountId) {
        subscribeRemoteCollator(for: accountId)
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
                self?.presenter?.didReceiveFee(.failure(error))
            }
        )
    }
}

extension ParaStkStakeSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension ParaStkStakeSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            presenter?.didReceiveError(error)
        }
    }
}

extension ParaStkStakeSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFee(result)
    }
}

extension ParaStkStakeSetupInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
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

extension ParaStkStakeSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
