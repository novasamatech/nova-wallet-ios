import UIKit
import Operation_iOS

final class StakingRemoveProxyInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingRemoveProxyInteractorOutputProtocol?
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let accountProviderFactory: AccountProviderFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let callFactory: SubstrateCallFactoryProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let chainAsset: ChainAsset
    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    let proxyAccount: ProxyAccount
    let signingWrapper: SigningWrapperProtocol

    init(
        proxyAccount: ProxyAccount,
        signingWrapper: SigningWrapperProtocol,
        chainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        accountProviderFactory: AccountProviderFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        selectedAccount: ChainAccountResponse,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.proxyAccount = proxyAccount
        self.extrinsicService = extrinsicService
        self.chainAsset = chainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.accountProviderFactory = accountProviderFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.callFactory = callFactory
        self.feeProxy = feeProxy
        self.selectedAccount = selectedAccount
        self.currencyManager = currencyManager
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = chainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let accountId = selectedAccount.accountId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        estimateFee()
    }
}

extension StakingRemoveProxyInteractor: StakingRemoveProxyInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        performPriceSubscription()
        performBalanceSubscription()
    }

    func estimateFee() {
        let call = callFactory.removeProxy(
            accountId: proxyAccount.accountId,
            type: proxyAccount.type
        )

        feeProxy.estimateFee(using: extrinsicService, reuseIdentifier: call.callName) { builder in
            try builder.adding(call: call)
        }
    }

    func remakeSubscriptions() {
        performPriceSubscription()
        performBalanceSubscription()
    }

    func submit() {
        let call = callFactory.removeProxy(
            accountId: proxyAccount.accountId,
            type: proxyAccount.type
        )

        extrinsicService.submit(
            { builder in
                try builder.adding(call: call)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                switch result {
                case let .success(model):
                    self?.presenter?.didSubmit(model: model)
                case let .failure(error):
                    self?.presenter?.didReceive(error: .submit(error))
                }
            }
        )
    }
}

extension StakingRemoveProxyInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
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

extension StakingRemoveProxyInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter?.didReceive(assetBalance: assetBalance)
        case let .failure(error):
            presenter?.didReceive(error: .balance(error))
        }
    }
}

extension StakingRemoveProxyInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        switch result {
        case let .success(fee):
            presenter?.didReceive(fee: fee)
        case let .failure(error):
            presenter?.didReceive(error: .fee(error))
        }
    }
}

extension StakingRemoveProxyInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
