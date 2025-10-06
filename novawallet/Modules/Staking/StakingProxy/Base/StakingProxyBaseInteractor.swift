import UIKit
import BigInt
import Operation_iOS

class StakingProxyBaseInteractor: RuntimeConstantFetching,
    StakingProxyBaseInteractorInputProtocol, AnyProviderAutoCleaning {
    weak var basePresenter: StakingProxyBaseInteractorOutputProtocol?
    let runtimeService: RuntimeCodingServiceProtocol
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let sharedState: RelaychainStakingSharedStateProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let operationQueue: OperationQueue

    var chainAsset: ChainAsset {
        sharedState.stakingOption.chainAsset
    }

    private var calculator = ProxyDepositCalculator()
    private var proxyProvider: AnyDataProvider<DecodedProxyDefinition>?
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    var proxyListLocalSubscriptionFactory: ProxyListLocalSubscriptionFactoryProtocol {
        sharedState.proxyLocalSubscriptionFactory
    }

    init(
        runtimeService: RuntimeCodingServiceProtocol,
        sharedState: RelaychainStakingSharedStateProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        selectedAccount: ChainAccountResponse,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.extrinsicService = extrinsicService
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.accountProviderFactory = accountProviderFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.callFactory = callFactory
        self.feeProxy = feeProxy
        self.selectedAccount = selectedAccount
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func fetchConstants() {
        fetchConstant(
            for: Proxy.depositBase,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(depositBase):
                self?.calculator.base = depositBase
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .fetchDepositBase(error))
            }
        }

        fetchConstant(
            for: Proxy.depositFactor,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(depositFactor):
                self?.calculator.factor = depositFactor
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .fetchDepositFactor(error))
            }
        }

        fetchConstant(
            for: Proxy.maxProxyCount,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<Int, Error>) in
            switch result {
            case let .success(maxCount):
                self?.basePresenter?.didReceive(maxProxies: maxCount)
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .fetchMaxProxyCount(error))
            }
        }

        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<BigUInt, Error>) in
            switch result {
            case let .success(existensialDeposit):
                self?.basePresenter?.didReceive(existensialDeposit: existensialDeposit)
            case let .failure(error):
                self?.basePresenter?.didReceive(baseError: .fetchED(error))
            }
        }
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            basePresenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    func performAccountSubscriptions() {
        clear(streamableProvider: &balanceProvider)
        clear(dataProvider: &proxyProvider)

        let chainId = chainAsset.chain.chainId
        let accountId = selectedAccount.accountId

        proxyProvider = subscribeProxies(
            for: accountId,
            chainId: chainId,
            modifyInternalList: ProxyFilter.allProxies
        )

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        estimateFee()
    }

    private func updateProxyDeposit() {
        let deposit = calculator.calculate()
        basePresenter?.didReceive(proxyDeposit: deposit)
    }

    // MARK: - StakingProxyBaseInteractorInputProtocol

    func setup() {
        feeProxy.delegate = self

        fetchConstants()
        performPriceSubscription()
        performAccountSubscriptions()
    }

    func estimateFee() {
        let call = callFactory.addProxy(
            accountId: proxyAccount(),
            type: .staking
        )

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: call.callName) { builder in
            try builder.adding(call: call)
        }
    }

    func refetchConstants() {
        fetchConstants()
    }

    func remakeSubscriptions() {
        performPriceSubscription()
        performAccountSubscriptions()
    }

    func proxyAccount() -> AccountId {
        AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize)
    }
}

extension StakingProxyBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        if chainAsset.asset.priceId == priceId {
            switch result {
            case let .success(priceData):
                basePresenter?.didReceive(price: priceData)
            case let .failure(error):
                basePresenter?.didReceive(baseError: .price(error))
            }
        }
    }
}

extension StakingProxyBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            basePresenter?.didReceive(assetBalance: assetBalance)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .balance(error))
        }
    }
}

extension StakingProxyBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(fee):
            basePresenter?.didReceive(fee: fee)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .fee(error))
        }
    }
}

extension StakingProxyBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}

extension StakingProxyBaseInteractor: ProxyListLocalSubscriptionHandler, ProxyListLocalStorageSubscriber {
    func handleProxies(result: Result<ProxyDefinition?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        switch result {
        case let .success(proxy):
            let proxyCount = proxy?.definition.count ?? 0
            calculator.proxyCount = proxyCount
            updateProxyDeposit()
            basePresenter?.didReceive(proxy: proxy)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .handleProxies(error))
            calculator.proxyCount = nil
            updateProxyDeposit()
            basePresenter?.didReceive(proxy: nil)
        }
    }
}
