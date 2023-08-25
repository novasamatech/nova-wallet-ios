import Foundation
import RobinHood

class NPoolsUnstakeBaseInteractor: AnyCancellableCleaning {
    weak var basePresenter: NPoolsUnstakeBaseInteractorOutputProtocol?
    
    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol

    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    
    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }
    
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var subpoolsProvider: AnyDataProvider<DecodedSubPools>?
    private var poolLedgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    
    private var currentPoolId: NominationPools.PoolId?
    private var poolAccountId: AccountId?
    
    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.npoolsOperationFactory = npoolsOperationFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }
    
    func provideBondedAccountId() {
        clear(cancellable: &bondedAccountIdCancellable)

        guard let poolId = currentPoolId else {
            return
        }

        bondedAccountIdCancellable = fetchBondedAccounts(
            for: npoolsOperationFactory,
            poolIds: { [poolId] },
            runtimeService: runtimeCodingService,
            operationQueue: operationQueue,
            completion: { [weak self] result in
                self?.bondedAccountIdCancellable = nil

                switch result {
                case let .success(accountIds):
                    if let accountId = accountIds[poolId] {
                        self?.poolAccountId = accountId
                        self?.setupBondedAccountProviders()
                    }
                case let .failure(error):
                    self?.presenter?.didReceive(error: .subscription(error, "bondedAccountId"))
                }
            }
        )
    }
    
    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }
        
        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        subpoolsProvider = subscribeSubPools(for: poolId, chainId: chainId)
        
        setupClaimableRewardsProvider()
    }

    func setupBondedAccountProviders() {
        poolLedgerProvider = nil

        guard let accountId = poolAccountId else {
            return
        }

        poolLedgerProvider = subscribeLedgerInfo(for: accountId, chainId: chainId)
    }

    func setupClaimableRewardsProvider() {
        guard let poolId = currentPoolId else {
            return
        }

        claimableRewardProvider = subscribeClaimableRewards(
            for: chainId,
            poolId: poolId,
            accountId: accountId
        )

        if claimableRewardProvider == nil {
            presenter?.didReceive(error: .claimableRewards(CommonError.dataCorruption))
        }
    }
    
    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
    
    func setupBasePoolProviders() {
        bondedPoolProvider = nil
        subpoolsProvider = nil
        poolLedgerProvider = nil
        
        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        balanceProvider = subscribeToAssetBalanceProvider(for: accountId, chainId: chainId, assetId: assetId)
        
        setupCurrencyProvider()
    }
}

extension NPoolsUnstakeBaseInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId: AccountId, chainId: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            self.currentPoolId = optPoolMember?.poolId
            
            setupPoolProviders()
            
            basePresenter?.didReceive(poolMember: optPoolMember)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    
}

extension NPoolsUnstakeBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId, chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            basePresenter?.didReceive(assetBalance: assetBalance)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "balance"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NPoolsUnstakeBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}
