import UIKit
import RobinHood
import BigInt

final class StakingSetupAmountInteractor: AnyProviderAutoCleaning, AnyCancellableCleaning {
    weak var presenter: StakingSetupAmountInteractorOutputProtocol?

    var chainAsset: ChainAsset { state.chainAsset }

    let state: RelaychainStartStakingStateProtocol
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let extrinsicFeeProxy: ExtrinsicFeeProxyProtocol
    let recommendationMediatorFactory: StakingRecommendationMediatorFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var locksProvider: StreamableProvider<AssetLock>?
    private var recommendationMediator: RelaychainStakingRecommendationMediating?

    init(
        state: RelaychainStartStakingStateProtocol,
        selectedAccount: ChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        extrinsicFeeProxy: ExtrinsicFeeProxyProtocol,
        recommendationMediatorFactory: StakingRecommendationMediatorFactoryProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.state = state
        self.selectedAccount = selectedAccount
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.extrinsicFeeProxy = extrinsicFeeProxy
        self.recommendationMediatorFactory = recommendationMediatorFactory
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func setupRecommendationMediator(for type: StakingType?) {
        if type == nil {
            recommendationMediator = recommendationMediatorFactory.createHybridStakingMediator(for: state)
        } else if type == .nominationPools {
            recommendationMediator = recommendationMediatorFactory.createPoolStakingMediator(for: state)
        } else {
            recommendationMediator = recommendationMediatorFactory.createDirectStakingMediator(for: state)
        }

        configureCurrentMediator()
    }

    private func configureCurrentMediator() {
        if recommendationMediator == nil {
            presenter?.didReceive(error: .recommendation(CommonError.dataCorruption))
            return
        }

        recommendationMediator?.delegate = self
        recommendationMediator?.startRecommending()
        recommendationMediator?.update(amount: 0)
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = chainAsset.chainAssetId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func performAssetLocksSubscription() {
        clear(streamableProvider: &locksProvider)

        let chainAssetId = chainAsset.chainAssetId

        locksProvider = subscribeToLocksProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func estimateDirectStakingFee(
        accountId: AccountId,
        amount: BigUInt,
        validators: PreparedValidators,
        feeId: TransactionFeeId,
        coderFactory: RuntimeCoderFactoryProtocol
    ) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let bondClosure = try Staking.Bond.appendCall(
                for: .accoundId(accountId),
                value: amount,
                payee: .staked,
                codingFactory: coderFactory
            )

            let callFactory = SubstrateCallFactory()

            let targets = validators.targets.map { $0.toSelected(for: nil) }
            let nominateCall = try callFactory.nominate(targets: targets)

            return try bondClosure(builder).adding(call: nominateCall)
        }

        extrinsicFeeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: feeId,
            setupBy: closure
        )
    }

    private func estimatePoolStakingFee(
        for pool: NominationPools.SelectedPool,
        amount: BigUInt,
        feeId: TransactionFeeId
    ) {
        let closure: ExtrinsicBuilderClosure = { builder in
            let call = NominationPools.JoinCall(amount: amount, poolId: pool.poolId)

            return try builder.adding(call: call.runtimeCall())
        }

        extrinsicFeeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: feeId,
            setupBy: closure
        )
    }
}

extension StakingSetupAmountInteractor: StakingSetupAmountInteractorInputProtocol, RuntimeConstantFetching {
    func setup() {
        extrinsicFeeProxy.delegate = self

        performAssetBalanceSubscription()
        performPriceSubscription()
        performAssetLocksSubscription()

        setupRecommendationMediator(for: state.stakingType)
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
        performAssetLocksSubscription()
    }

    func remakeRecommendationSetup() {
        recommendationMediator?.stopRecommending()

        setupRecommendationMediator(for: state.stakingType)
    }

    func estimateFee(for staking: SelectedStakingOption, amount: BigUInt, feeId: TransactionFeeId) {
        let accountId = selectedAccount.accountId

        switch staking {
        case let .direct(preparedValidators):
            runtimeProvider.fetchCoderFactory(
                runningIn: OperationManager(operationQueue: operationQueue),
                completion: { [weak self] coderFactory in
                    self?.estimateDirectStakingFee(
                        accountId: accountId,
                        amount: amount,
                        validators: preparedValidators,
                        feeId: feeId,
                        coderFactory: coderFactory
                    )
                }, errorClosure: { [weak self] error in
                    self?.presenter?.didReceive(error: .fee(error, feeId))
                }
            )
        case let .pool(selectedPool):
            estimatePoolStakingFee(for: selectedPool, amount: amount, feeId: feeId)
        }
    }

    func updateRecommendation(for amount: BigUInt) {
        recommendationMediator?.update(amount: amount)
    }
}

extension StakingSetupAmountInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: TransactionFeeId) {
        switch result {
        case let .success(info):
            presenter?.didReceive(fee: BigUInt(info.fee), feeId: identifier)
        case let .failure(error):
            presenter?.didReceive(error: .fee(error, identifier))
        }
    }
}

extension StakingSetupAmountInteractor: RelaychainStakingRecommendationDelegate {
    func didReceive(recommendation: RelaychainStakingRecommendation, amount: BigUInt) {
        presenter?.didReceive(recommendation: recommendation, amount: amount)
    }

    func didReceiveRecommendation(error: Error) {
        presenter?.didReceive(error: .recommendation(error))
    }
}

extension StakingSetupAmountInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chainAsset.chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccount.accountId else {
            return
        }

        switch result {
        case let .success(balance):
            let balance = balance ?? .createZero(
                for: .init(chainId: chainId, assetId: assetId),
                accountId: accountId
            )
            presenter?.didReceive(assetBalance: balance)
        case let .failure(error):
            presenter?.didReceive(error: .assetBalance(error))
        }
    }

    func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == chainAsset.chain.chainId,
            assetId == chainAsset.asset.assetId,
            accountId == selectedAccount.accountId else {
            return
        }

        switch result {
        case let .success(changes):
            let locks = changes.mergeToDict([:]).values
            presenter?.didReceive(locks: Array(locks))
        case let .failure(error):
            presenter?.didReceive(error: .locks(error))
        }
    }
}

extension StakingSetupAmountInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                presenter?.didReceive(price: priceData)
            case let .failure(error):
                presenter?.didReceive(error: .price(error))
            }
        }
    }
}

extension StakingSetupAmountInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
