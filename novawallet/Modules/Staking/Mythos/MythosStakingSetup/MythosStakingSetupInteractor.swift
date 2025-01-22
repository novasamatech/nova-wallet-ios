import UIKit
import SubstrateSdk
import Operation_iOS

final class MythosStakingSetupInteractor {
    weak var presenter: MythosStakingSetupInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?
    let frozenBalanceStore: MythosStakingFrozenBalanceStore
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var collatorSubscription: CallbackStorageSubscription<MythosStakingPallet.CandidateInfo>?
    private let collatorsCancellable = CancellableCallStore()

    private lazy var localKeyFactory = LocalStorageKeyFactory()

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        preferredCollatorFactory: PreferredStakingCollatorFactoryProtocol?,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingDetailsService = stakingDetailsService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.preferredCollatorFactory = preferredCollatorFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.repositoryFactory = repositoryFactory
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
}

extension MythosStakingSetupInteractor {
    private func makeAssetBalanceSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    private func makeFrozenBalanceSubscription() {
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

    private func makeMinStakeSubscription() {
        minStakeProvider = subscribeToMinStake(for: chainAsset.chain.chainId)
    }

    private func makePriceSubscription() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider?.removeObserver(self)

            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func makeStakingDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.presenter?.didReceiveDetails(newState)
        }
    }

    private func subscribeRemoteCollator(for accountId: AccountId) {
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
                self?.presenter?.didReceiveError(.preferredCollator(error))
            }
        }
    }
}

extension MythosStakingSetupInteractor: MythosStakingSetupInteractorInputProtocol {
    func setup() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeFrozenBalanceSubscription()

        makeStakingDetailsSubscription()
        makeMinStakeSubscription()

        providePreferredCollator()
    }

    func applyCollator(with accountId: AccountId) {
        subscribeRemoteCollator(for: accountId)
    }

    func estimateFee(with _: MythosStakeModel) {}
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

extension MythosStakingSetupInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
