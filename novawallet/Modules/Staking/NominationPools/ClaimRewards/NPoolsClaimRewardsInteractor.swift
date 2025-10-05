import UIKit
import Operation_iOS
import SubstrateSdk
import BigInt

final class NPoolsClaimRewardsInteractor: RuntimeConstantFetching, AnyProviderAutoCleaning,
    NominationPoolStakingMigrating {
    weak var presenter: NPoolsClaimRewardsInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let signingWrapper: SigningWrapperProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    let npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var poolMemberProvider: AnyDataProvider<DecodedPoolMember>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var rewardPoolProvider: AnyDataProvider<DecodedRewardPool>?
    private var claimableRewardProvider: AnySingleValueProvider<String>?
    private var delegatedStakingProvider: AnyDataProvider<DecodedDelegatedStakingDelegator>?
    private var cancellableNeedsMigration = CancellableCallStore()

    private var currentPoolId: NominationPools.PoolId?
    private var currentPoolRewardCounter: BigUInt?
    private var currentMemberRewardCounter: BigUInt?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        runtimeService: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicMonitorFactory: ExtrinsicSubmitMonitorFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        signingWrapper: SigningWrapperProtocol,
        npoolsLocalSubscriptionFactory: NPoolsLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.extrinsicMonitorFactory = extrinsicMonitorFactory
        self.feeProxy = feeProxy
        self.signingWrapper = signingWrapper
        self.npoolsLocalSubscriptionFactory = npoolsLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    func setupPoolProviders() {
        guard let poolId = currentPoolId else {
            return
        }

        rewardPoolProvider = subscribeRewardPool(for: poolId, chainId: chainId)

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
            presenter?.didReceive(error: .subscription(CommonError.dataCorruption, "rewards"))
        }
    }

    func setupCurrencyProvider() {
        guard let priceId = asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func setupBaseProviders() {
        rewardPoolProvider = nil
        claimableRewardProvider = nil

        poolMemberProvider = subscribePoolMember(for: accountId, chainId: chainId)
        balanceProvider = subscribeToAssetBalanceProvider(for: accountId, chainId: chainId, assetId: assetId)

        clear(dataProvider: &delegatedStakingProvider)
        delegatedStakingProvider = subscribeDelegatedStaking(for: accountId, chainId: chainId)

        setupCurrencyProvider()
    }

    func createExtrinsicBuilderClosure(
        for strategy: StakingClaimRewardsStrategy,
        accountId: AccountId,
        needsMigration: Bool
    ) -> ExtrinsicBuilderClosure {
        { builder in
            let currentBuilder = try NominationPools.migrateIfNeeded(
                needsMigration,
                accountId: accountId,
                builder: builder
            )

            switch strategy {
            case .restake:
                let bondExtra = NominationPools.BondExtraCall(extra: .rewards)
                return try currentBuilder.adding(call: bondExtra.runtimeCall())
            case .freeBalance:
                let claimRewards = NominationPools.ClaimRewardsCall()
                return try currentBuilder.adding(call: claimRewards.runtimeCall())
            }
        }
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(existentialDeposit):
                self?.presenter?.didReceive(existentialDeposit: existentialDeposit)
            case let .failure(error):
                self?.presenter?.didReceive(error: .existentialDeposit(error))
            }
        }
    }
}

extension NPoolsClaimRewardsInteractor: NPoolsClaimRewardsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        setupBaseProviders()
        provideExistentialDeposit()
    }

    func remakeSubscriptions() {
        setupBaseProviders()
    }

    func retryExistentialDeposit() {
        provideExistentialDeposit()
    }

    func estimateFee(for strategy: StakingClaimRewardsStrategy, needsMigration: Bool) {
        let identifier = strategy.rawValue + "-" + "\(needsMigration)"

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: identifier,
            setupBy: createExtrinsicBuilderClosure(
                for: strategy,
                accountId: accountId,
                needsMigration: needsMigration
            )
        )
    }

    func submit(for strategy: StakingClaimRewardsStrategy, needsMigration: Bool) {
        let wrapper = extrinsicMonitorFactory.submitAndMonitorWrapper(
            extrinsicBuilderClosure: createExtrinsicBuilderClosure(
                for: strategy,
                accountId: accountId,
                needsMigration: needsMigration
            ),
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(submissionResult: result.mapToExtrinsicSubmittedResult())
        }
    }
}

extension NPoolsClaimRewardsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(feeInfo):
            presenter?.didReceive(fee: feeInfo)
        case let .failure(error):
            presenter?.didReceive(error: .fee(error))
        }
    }
}

extension NPoolsClaimRewardsInteractor: NPoolsLocalStorageSubscriber, NPoolsLocalSubscriptionHandler {
    func handlePoolMember(
        result: Result<NominationPools.PoolMember?, Error>,
        accountId _: AccountId, chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(optPoolMember):
            if currentPoolId != optPoolMember?.poolId {
                currentPoolId = optPoolMember?.poolId

                setupPoolProviders()
            }

            if currentMemberRewardCounter != optPoolMember?.lastRecordedRewardCounter {
                currentMemberRewardCounter = optPoolMember?.lastRecordedRewardCounter

                claimableRewardProvider?.refresh()
            }
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "pool member"))
        }
    }

    func handleClaimableRewards(
        result: Result<BigUInt?, Error>,
        chainId _: ChainModel.Id,
        poolId _: NominationPools.PoolId,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(rewards):
            presenter?.didReceive(claimableRewards: rewards)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "rewards"))
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

    func handleDelegatedStaking(
        result: Result<DelegatedStakingPallet.Delegation?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(delegation):
            cancellableNeedsMigration.cancel()

            needsPoolStakingMigration(
                for: delegation,
                runtimeProvider: runtimeService,
                cancellableStore: cancellableNeedsMigration,
                operationQueue: operationQueue
            ) { [weak self] result in
                switch result {
                case let .success(needsMigration):
                    self?.presenter?.didReceive(needsMigration: needsMigration)
                case let .failure(error):
                    self?.presenter?.didReceive(error: .subscription(error, "Needs Migration"))
                }
            }
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "Delegated Staking"))
        }
    }
}

extension NPoolsClaimRewardsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            // we can have case when user have np staking but no native balance
            let balanceOrZero = assetBalance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )

            presenter?.didReceive(assetBalance: balanceOrZero)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "balance"))
        }
    }
}

extension NPoolsClaimRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceive(price: priceData)
        case let .failure(error):
            presenter?.didReceive(error: .subscription(error, "price"))
        }
    }
}

extension NPoolsClaimRewardsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        setupCurrencyProvider()
    }
}
