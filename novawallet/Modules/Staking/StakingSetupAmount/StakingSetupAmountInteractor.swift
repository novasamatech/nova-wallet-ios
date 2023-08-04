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
    let recommendationMediatorFactory: StakingRecommendationMediatorFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var recommendationMediator: RelaychainStakingRecommendationMediating?

    private var lastRecommendedOption: SelectedStakingOption?

    init(
        state: RelaychainStartStakingStateProtocol,
        selectedAccount: ChainAccountResponse,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
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

        recommendationMediator?.delegate = self
        recommendationMediator?.startRecommending()
        recommendationMediator?.update(amount: 0)

        if recommendationMediator == nil {
            presenter?.didReceive(error: .recommendation(CommonError.dataCorruption))
            return
        }
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

    private func estimateDirectStakingFee(
        accountId: AccountId,
        amount: BigUInt,
        validators: PreparedValidators,
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

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceive(
                    fee: BigUInt(info.fee),
                    stakingOption: .direct(validators),
                    amount: amount
                )
            case let .failure(error):
                self?.presenter?.didReceive(error: .fee(error))
            }
        }
    }

    private func estimatePoolStakingFee(
        for _: AccountId,
        amount _: BigUInt,
        pool _: NominationPools.SelectedPool
    ) {}
}

extension StakingSetupAmountInteractor: StakingSetupAmountInteractorInputProtocol, RuntimeConstantFetching {
    func setup() {
        performAssetBalanceSubscription()
        performPriceSubscription()

        setupRecommendationMediator(for: state.stakingType)
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
    }

    func remakeRecommendationSetup() {
        recommendationMediator?.stopRecommending()

        setupRecommendationMediator(for: state.stakingType)
    }

    func estimateFee(for amount: BigUInt) {
        guard let selectionOption = lastRecommendedOption else {
            return
        }

        let accountId = selectedAccount.accountId

        switch selectionOption {
        case let .direct(preparedValidators):
            runtimeProvider.fetchCoderFactory(
                runningIn: OperationManager(operationQueue: operationQueue),
                completion: { [weak self] coderFactory in
                    self?.estimateDirectStakingFee(
                        accountId: accountId,
                        amount: amount,
                        validators: preparedValidators,
                        coderFactory: coderFactory
                    )
                }, errorClosure: { [weak self] error in
                    self?.presenter?.didReceive(error: .fee(error))
                }
            )
        case let .pool(selectedPool):
            estimatePoolStakingFee(
                for: accountId,
                amount: amount,
                pool: selectedPool
            )
        }
    }

    func updateRecommendation(for amount: BigUInt) {
        recommendationMediator?.update(amount: amount)
    }

    func replaceWithManual(option: SelectedStakingOption) {
        lastRecommendedOption = option

        switch option {
        case .direct:
            setupRecommendationMediator(for: .relaychain)
        case .pool:
            setupRecommendationMediator(for: .nominationPools)
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
