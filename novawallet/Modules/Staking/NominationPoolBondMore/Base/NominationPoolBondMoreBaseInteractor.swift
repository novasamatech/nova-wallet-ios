import UIKit
import RobinHood
import BigInt

class NominationPoolBondMoreBaseInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning, NominationPoolsDataProviding {
    weak var basePresenter: NominationPoolBondMoreBaseInteractorOutputProtocol?
    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let feeProxy: ExtrinsicFeeProxyProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let npoolsOperationFactory: NominationPoolsOperationFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol

    private var operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var poolLedgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?

    private var bondedAccountIdCancellable: CancellableCall?

    private var accountId: AccountId { selectedAccount.chainAccount.accountId }
    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?
    private var poolAccountId: AccountId?

    var chainId: ChainModel.Id { chainAsset.chain.chainId }

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.feeProxy = feeProxy
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.callFactory = callFactory
        self.npoolsOperationFactory = npoolsOperationFactory
        self.runtimeService = runtimeService
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory

        extrinsicService = extrinsicServiceFactory.createService(
            account: selectedAccount.chainAccount,
            chain: chainAsset.chain
        )

        self.currencyManager = currencyManager
    }

    private func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            basePresenter?.didReceive(price: nil)
        }
    }

    private func subscribeAccountBalance() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func provideBondedAccountId() {
        clear(cancellable: &bondedAccountIdCancellable)

        guard let poolId = currentPoolId else {
            return
        }

        bondedAccountIdCancellable = fetchBondedAccounts(
            for: npoolsOperationFactory,
            poolIds: { [poolId] },
            runtimeService: runtimeService,
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
                    self?.basePresenter?.didReceive(error: .subscription(error, "bondedAccountId"))
                }
            }
        )
    }

    func setupBondedAccountProviders() {
        poolLedgerProvider = nil

        guard let accountId = poolAccountId else {
            return
        }

        poolLedgerProvider = subscribeLedgerInfo(for: accountId, chainId: chainId)
    }

    func createExtrinsicClosure(for points: BigUInt) -> ExtrinsicBuilderClosure {
        { builder in
            let call = NominationPools.BondExtraCall(extra: .freeBalance(points))
            return try builder.adding(call: call.runtimeCall())
        }
    }

    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        setupClaimableRewardsProvider()
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
            basePresenter?.didReceive(error: .claimableRewards(CommonError.dataCorruption))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: NominationPoolBondMoreBaseInteractorInputProtocol {
    func setup() {
        subscribeAccountBalance()
        subscribePrice()
        provideBondedAccountId()
    }

    func estimateFee(for points: BigUInt) {
        let reuseIdentifier = String(points)
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: createExtrinsicClosure(for: points)
        )
    }
}

extension NominationPoolBondMoreBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceive(price: priceData)
        case let .failure(error):
            basePresenter?.didReceive(error: .fetchPriceFailed(error))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            basePresenter?.didReceive(error: .fetchBalanceFailed(error))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(dispatchInfo):
            let fee = BigUInt(dispatchInfo.fee)
            basePresenter?.didReceive(fee: fee)
        case let .failure(error):
            basePresenter?.didReceive(error: .fetchFeeFailed(error))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}

extension NominationPoolBondMoreBaseInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            if currentPoolId != optPoolMember?.poolId {
                currentPoolId = optPoolMember?.poolId

                setupPoolProviders()
                provideBondedAccountId()
            }

            if currentMemberRewardCounter != optPoolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = optPoolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }

            basePresenter?.didReceive(poolMember: optPoolMember)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleRewardPool(
        result: Result<NominationPools.RewardPool?, Error>,
        poolId: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        guard currentPoolId == poolId else {
            return
        }

        if case let .success(rewardPool) = result, rewardPool?.lastRecordedRewardCounter != currentPoolRewardCounter {
            self.currentPoolRewardCounter = rewardPool?.lastRecordedRewardCounter

            claimableRewardProvider?.refresh()
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleLedgerInfo(
        result: Result<StakingLedger?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(ledger):
            basePresenter?.didReceive(stakingLedger: ledger)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "ledger"))
        }
    }
}
