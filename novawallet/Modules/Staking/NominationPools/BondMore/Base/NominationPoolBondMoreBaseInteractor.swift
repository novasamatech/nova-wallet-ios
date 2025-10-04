import UIKit
import Operation_iOS
import BigInt
import SubstrateSdk

class NominationPoolBondMoreBaseInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning,
    NominationPoolsDataProviding, NominationPoolStakingMigrating {
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
    let assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol
    let operationQueue: OperationQueue

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var bondedPoolProvider: AnyDataProvider<DecodedBondedPool>?
    private var delegatedStakingProvider: AnyDataProvider<DecodedDelegatedStakingDelegator>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var cancellableNeedsMigration = CancellableCallStore()

    private var bondedAccountIdCancellable: CancellableCall?
    private var assetExistenceCancellable: CancellableCall?

    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?
    private var poolAccountId: AccountId?

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        runtimeService: RuntimeCodingServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        npoolsOperationFactory: NominationPoolsOperationFactoryProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        assetStorageInfoFactory: AssetStorageInfoOperationFactoryProtocol,
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
        self.assetStorageInfoFactory = assetStorageInfoFactory

        self.extrinsicService = extrinsicService

        self.currencyManager = currencyManager
    }

    func subscribeAccountBalance() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func subscribePrice() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        } else {
            basePresenter?.didReceive(price: nil)
        }
    }

    func subscribeDelegatedStaking() {
        clear(dataProvider: &delegatedStakingProvider)

        delegatedStakingProvider = subscribeDelegatedStaking(
            for: accountId,
            chainId: chainId
        )
    }

    func createExtrinsicClosure(
        for points: BigUInt,
        accountId: AccountId,
        needsMigration: Bool
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let currentBuilder = try NominationPools.migrateIfNeeded(
                needsMigration,
                accountId: accountId,
                builder: builder
            )

            let bondExtraCall = NominationPools.BondExtraCall(extra: .freeBalance(points))
            return try currentBuilder.adding(call: bondExtraCall.runtimeCall())
        }
    }

    func subscribePoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        bondedPoolProvider = subscribeBondedPool(for: poolId, chainId: chainId)
        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)

        subscribeClaimableRewardsProvider()
    }

    func subscribeClaimableRewardsProvider() {
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

    func subscribePoolMember() {
        clear(dataProvider: &poolMemberProvider)
        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
    }

    private func provideNeedsMigration(for delegation: DelegatedStakingPallet.Delegation?) {
        cancellableNeedsMigration.cancel()

        needsPoolStakingMigration(
            for: delegation,
            runtimeProvider: runtimeService,
            cancellableStore: cancellableNeedsMigration,
            operationQueue: operationQueue
        ) { [weak self] result in
            switch result {
            case let .success(needsMigration):
                self?.basePresenter?.didReceive(needsMigration: needsMigration)
            case let .failure(error):
                self?.basePresenter?.didReceive(error: .subscription(error, "Unexpected delegated staking error"))
            }
        }
    }

    func provideAssetExistence() {
        let assetInfoWrapper = assetStorageInfoFactory.createStorageInfoWrapper(
            from: chainAsset.asset,
            runtimeProvider: runtimeService
        )

        let assetBalanceExistenceWrapper: CompoundOperationWrapper<AssetBalanceExistence?> =
            OperationCombiningService.compoundWrapper(operationManager: operationManager) { [weak self] in
                guard let self = self else {
                    return nil
                }
                let assetInfo = try assetInfoWrapper.targetOperation.extractNoCancellableResultData()

                return self.assetStorageInfoFactory.createAssetBalanceExistenceOperation(
                    for: assetInfo,
                    chainId: self.chainAsset.chain.chainId,
                    asset: self.chainAsset.asset
                )
            }
        assetBalanceExistenceWrapper.addDependency(wrapper: assetInfoWrapper)

        let wrapper = CompoundOperationWrapper<AssetBalanceExistence?>(
            targetOperation: assetBalanceExistenceWrapper.targetOperation,
            dependencies: assetInfoWrapper.allOperations + assetBalanceExistenceWrapper.dependencies
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                guard self?.assetExistenceCancellable === wrapper else {
                    return
                }
                self?.assetExistenceCancellable = nil

                do {
                    let assetExistence = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.basePresenter?.didReceive(assetBalanceExistance: assetExistence)
                } catch {
                    self?.basePresenter?.didReceive(error: .assetExistance(error))
                }
            }
        }

        assetExistenceCancellable = wrapper

        operationQueue.addOperations(
            wrapper.allOperations,
            waitUntilFinished: false
        )
    }
}

extension NominationPoolBondMoreBaseInteractor: NominationPoolBondMoreBaseInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        subscribeAccountBalance()
        subscribePoolMember()
        subscribePrice()
        subscribeDelegatedStaking()
        provideAssetExistence()
    }

    func estimateFee(for amount: BigUInt, needsMigration: Bool) {
        let reuseIdentifier = String(amount) + "-" + "\(needsMigration)"
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: reuseIdentifier,
            setupBy: createExtrinsicClosure(
                for: amount,
                accountId: accountId,
                needsMigration: needsMigration
            )
        )
    }

    func retrySubscriptions() {
        subscribeAccountBalance()
        subscribePoolMember()
        subscribePrice()
        subscribeDelegatedStaking()
    }

    func retryClaimableRewards() {
        subscribeClaimableRewardsProvider()
    }

    func retryAssetExistance() {
        provideAssetExistence()
    }
}

extension NominationPoolBondMoreBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            // we can have case when user have np staking but no native balance
            let balanceOrZero = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            basePresenter?.didReceive(assetBalance: balanceOrZero)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "asset balance"))
        }
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
            basePresenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NominationPoolBondMoreBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            basePresenter?.didReceive(fee: feeInfo)
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
    func handleDelegatedStaking(
        result: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(delegation):
            provideNeedsMigration(for: delegation)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "Delegated staking failed"))
        }
    }

    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(poolMember):
            if currentPoolId != poolMember?.poolId {
                currentPoolId = poolMember?.poolId

                subscribePoolProviders()
            }

            if currentMemberRewardCounter != poolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = poolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }

            basePresenter?.didReceive(poolMember: poolMember)
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

    func handleBondedPool(
        result: Result<NominationPools.BondedPool?, Error>,
        poolId _: NominationPools.PoolId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(bondedPool):
            basePresenter?.didReceive(bondedPool: bondedPool)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "bonded pool"))
        }
    }

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId: NominationPools.PoolId,
        accountId _: AccountId
    ) {
        guard currentPoolId == poolId else {
            return
        }

        switch result {
        case let .success(rewards):
            basePresenter?.didReceive(claimableRewards: rewards)
        case let .failure(error):
            basePresenter?.didReceive(error: .subscription(error, "claimable rewards"))
        }
    }
}
