import UIKit
import BigInt
import RobinHood

class StakingProxyBaseInteractor: RuntimeConstantFetching, StakingProxyBaseInteractorInputProtocol {
    weak var basePresenter: StakingProxyBaseInteractorOutputProtocol?
    let runtimeService: RuntimeCodingServiceProtocol
    let selectedAccount: ChainAccountResponse
    let chainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol
    let sharedState: RelaychainStakingSharedStateProtocol

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
    private var calculator = ProxyDepositCalculator()
    private var proxyProvider: AnyDataProvider<DecodedProxyDefinition>?
    private let operationQueue: OperationQueue
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var extrinsicService: ExtrinsicServiceProtocol?
    private var controllerAccountProvider: StreamableProvider<MetaAccountModel>?
    private var stashAccountProvider: StreamableProvider<MetaAccountModel>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?
    private var stashItem: StashItem?

    var stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol {
        sharedState.localSubscriptionFactory
    }

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
        extrinsicServiceFactory: ExtrinsicServiceFactoryProtocol,
        selectedAccount: ChainAccountResponse,
        chainAsset: ChainAsset,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.runtimeService = runtimeService
        self.sharedState = sharedState
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.accountProviderFactory = accountProviderFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicServiceFactory = extrinsicServiceFactory
        self.callFactory = callFactory
        self.feeProxy = feeProxy
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func fetchConstants() {
        fetchConstant(
            for: Proxy.depositBase,
            runtimeCodingService: runtimeService,
            operationManager: operationManager
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
            operationManager: operationManager
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
            operationManager: operationManager
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
            operationManager: operationManager
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

    func handle(stashItem: StashItem?) {
        self.stashItem = stashItem

        clear(streamableProvider: &balanceProvider)
        clear(streamableProvider: &stashAccountProvider)
        clear(dataProvider: &proxyProvider)

        if
            let stashItem = stashItem,
            let stashAccountId = try? stashItem.stash.toAccountId() {
            let chainId = chainAsset.chain.chainId
            proxyProvider = subscribeProxies(
                for: stashAccountId,
                chainId: chainId,
                modifyInternalList: ProxyFilter.allProxies
            )
            balanceProvider = subscribeToAssetBalanceProvider(
                for: stashAccountId,
                chainId: chainAsset.chain.chainId,
                assetId: chainAsset.asset.assetId
            )

            subscribeToControllerAccount(address: stashItem.controller, chain: chainAsset.chain)

            if stashItem.controller != stashItem.stash {
                subscribeToStashAccount(address: stashItem.stash, chain: chainAsset.chain)
            }

            estimateFee()
        }
    }

    private func updateProxyDeposit() {
        let deposit = calculator.calculate()
        basePresenter?.didReceive(proxyDeposit: deposit)
    }

    private func subscribeToControllerAccount(address: AccountAddress, chain: ChainModel) {
        clear(streamableProvider: &controllerAccountProvider)
        guard controllerAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        controllerAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    private func subscribeToStashAccount(address: AccountAddress, chain: ChainModel) {
        clear(streamableProvider: &stashAccountProvider)
        guard stashAccountProvider == nil, let accountId = try? address.toAccountId() else {
            return
        }

        stashAccountProvider = subscribeForAccountId(accountId, chain: chain)
    }

    // MARK: - StakingProxyBaseInteractorInputProtocol

    func setup() {
        if let address = selectedAccount.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address, chainId: chainAsset.chain.chainId)
        }

        feeProxy.delegate = self

        fetchConstants()
        performPriceSubscription()
    }

    func estimateFee() {
        guard
            let extrinsicService = self.extrinsicService else {
            return
        }

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
        if let stashItem = stashItem {
            handle(stashItem: stashItem)
        }
    }

    func proxyAccount() -> AccountId {
        AccountId.zeroAccountId(of: chainAsset.chain.accountIdSize)
    }
}

extension StakingProxyBaseInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler,
    AnyProviderAutoCleaning {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        switch result {
        case let .success(stashItem):
            handle(stashItem: stashItem)
        case let .failure(error):
            basePresenter?.didReceive(baseError: .stashItem(error))
        }
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

extension StakingProxyBaseInteractor: AccountLocalSubscriptionHandler, AccountLocalStorageSubscriber {
    func handleAccountResponse(
        result: Result<MetaChainAccountResponse?, Error>,
        accountId _: AccountId,
        chain _: ChainModel
    ) {
        switch result {
        case let .success(optAccount):
            if let account = optAccount {
                extrinsicService = extrinsicServiceFactory.createService(
                    account: account.chainAccount,
                    chain: chainAsset.chain
                )
                estimateFee()
            }
        case .failure:
            extrinsicService = nil
            estimateFee()
        }
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
