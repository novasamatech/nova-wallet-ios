import UIKit
import SubstrateSdk
import Operation_iOS

final class MythosStakingSetupInteractor: RuntimeConstantFetching {
    weak var presenter: MythosStakingSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let rewardService: CollatorStakingRewardCalculatorServiceProtocol
    let frozenBalanceStore: MythosStakingFrozenBalanceStore
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let identityProxyFactory: IdentityProxyFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var collatorSubscription: CallbackStorageSubscription<MythosStakingPallet.CandidateInfo>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?
    private var delegatorIdentityCancellable = CancellableCallStore()

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        rewardService: CollatorStakingRewardCalculatorServiceProtocol,
        preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        identityProxyFactory: IdentityProxyFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingDetailsService = stakingDetailsService
        self.rewardService = rewardService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.preferredCollatorFactory = preferredCollatorFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.repositoryFactory = repositoryFactory
        self.identityProxyFactory = identityProxyFactory
        self.operationQueue = operationQueue
        self.logger = logger

        frozenBalanceStore = MythosStakingFrozenBalanceStore(
            accountId: selectedAccount.accountId,
            chainAssetId: chainAsset.chainAssetId,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            logger: logger
        )

        self.currencyManager = currencyManager
    }

    deinit {
        delegatorIdentityCancellable.cancel()
    }

    func getExtrinsicBuilderClosure(from model: MythosStakeModel) -> ExtrinsicBuilderClosure {
        { builder in
            var resultBuilder = builder

            if model.amount.toLock > 0 {
                let lockCall = MythosStakingPallet.LockCall(amount: model.amount.toLock)
                resultBuilder = try resultBuilder.adding(call: lockCall.runtimeCall())
            }

            let stakeCall = MythosStakingPallet.StakeCall(
                targets: [
                    MythosStakingPallet.StakeTarget(
                        candidate: model.collator,
                        stake: model.amount.toStake
                    )
                ]
            )

            return try resultBuilder.adding(call: stakeCall.runtimeCall())
        }
    }
}

private extension MythosStakingSetupInteractor {
    func makeAssetBalanceSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makeFrozenBalanceSubscription() {
        frozenBalanceStore.setup()

        frozenBalanceStore.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let frozenBalance = newState {
                self?.presenter?.didReceiveFrozenBalance(frozenBalance)
            }
        }
    }

    func makeMinStakeSubscription() {
        minStakeProvider = subscribeToMinStake(for: chainAsset.chain.chainId)
    }

    func makePriceSubscription() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider?.removeObserver(self)

            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeStakingDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState, !newState.stakeDistribution.isEmpty {
                self?.provideIdentities(for: Array(newState.stakeDistribution.keys))
            }

            self?.presenter?.didReceiveDetails(newState)
        }
    }

    func makeBlockNumberSubscription() {
        blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)
    }

    func provideRewardCalculator() {
        let operation = rewardService.fetchCalculatorOperation()

        execute(
            operation: operation,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(calculator):
                self?.presenter?.didReceiveRewardCalculator(calculator)
            case let .failure(error):
                self?.logger.error("Reward calculator error: \(error)")
            }
        }
    }

    func subscribeRemoteCollator(for accountId: AccountId) {
        collatorSubscription = nil

        do {
            let storagePath = MythosStakingPallet.candidatesPath
            let localKey = try localKeyFactory.createFromStoragePath(
                storagePath,
                accountId: accountId,
                chainId: chainAsset.chain.chainId
            )

            let repository = repositoryFactory.createChainStorageItemRepository()

            let request = MapSubscriptionRequest(
                storagePath: storagePath,
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
                    self?.presenter?.didReceiveCandidateInfo(collator)
                case let .failure(error):
                    self?.logger.error("Collator info subscription failed: \(error)")
                }
            }
        } catch {
            logger.error("Unexpected collator subscription failed: \(error)")
        }
    }

    func provideIdentities(for delegations: [AccountId]) {
        delegatorIdentityCancellable.cancel()

        let wrapper = identityProxyFactory.createIdentityWrapperByAccountId(for: { delegations })

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: delegatorIdentityCancellable,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(identities):
                self?.presenter?.didReceiveDelegationIdentities(identities)
            case let .failure(error):
                self?.logger.error("Identities error: \(error)")
            }
        }
    }

    func providePreferredCollator() {
        guard let operationFactory = preferredCollatorFactory else {
            presenter?.didReceivePreferredCollator(nil)
            return
        }

        let wrapper = operationFactory.createPreferredCollatorWrapper()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(optCollator):
                self?.presenter?.didReceivePreferredCollator(optCollator)
            case let .failure(error):
                self?.logger.error("Preferred collator error: \(error)")
                self?.presenter?.didReceivePreferredCollator(nil)
            }
        }
    }

    func provideMaxCandidatesPerStaker() {
        fetchConstant(
            for: MythosStakingPallet.maxStakedCandidatesPath,
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<UInt32, Error>) in
            switch result {
            case let .success(maxCandidatesPerStaker):
                self?.presenter?.didReceiveMaxCollatorsPerStaker(maxCandidatesPerStaker)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }
}

extension MythosStakingSetupInteractor: MythosStakingSetupInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeFrozenBalanceSubscription()
        makeBlockNumberSubscription()

        makeStakingDetailsSubscription()
        makeMinStakeSubscription()

        providePreferredCollator()
        provideRewardCalculator()

        provideMaxCandidatesPerStaker()
    }

    func applyCollator(with accountId: AccountId) {
        subscribeRemoteCollator(for: accountId)
    }

    func estimateFee(with model: MythosStakeModel) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: model.reuseTxId,
            payingIn: nil,
            setupBy: getExtrinsicBuilderClosure(from: model)
        )
    }
}

extension MythosStakingSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(model):
            presenter?.didReceiveFee(model)
        case let .failure(error):
            presenter?.didReceiveError(.feeFailed(error))
        }
    }
}

extension MythosStakingSetupInteractor: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleMinStake(
        result: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(minStake):
            if let minStake {
                presenter?.didReceiveMinStakeAmount(minStake)
            }
        case let .failure(error):
            logger.error("Min stake subscription failed: \(error)")
        }
    }
}

extension MythosStakingSetupInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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
            logger.error("Balance subscription failed: \(error)")
        }
    }
}

extension MythosStakingSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription failed: \(error)")
        }
    }
}

extension MythosStakingSetupInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension MythosStakingSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
