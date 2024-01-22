import UIKit
import RobinHood

final class StakingRemoveProxyInteractor: StakingRemoveProxyInteractorInputProtocol, AnyProviderAutoCleaning {
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

    let proxyAccount: AccountAddress
    let signingWrapper: SigningWrapperProtocol

    init(
        proxyAccount: AccountAddress,
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

    func performBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let accountId = selectedAccount.accountId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        estimateFee()
    }

    // MARK: - StakingProxyBaseInteractorInputProtocol

    func setup() {
        feeProxy.delegate = self

        performPriceSubscription()
        performBalanceSubscription()
    }

    func estimateFee() {
        guard let proxyAccountId = try? proxyAccount.toAccountId(
            using: chainAsset.chain.chainFormat
        ) else {
            return
        }

        let call = callFactory.removeProxy(
            accountId: proxyAccountId,
            type: .staking
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
        guard let proxyAccountId = try? proxyAccount.toAccountId(
            using: chainAsset.chain.chainFormat
        ) else {
            presenter?.didReceive(error: .submit(CommonError.undefined))
            return
        }

        let call = callFactory.removeProxy(
            accountId: proxyAccountId,
            type: .staking
        )

        extrinsicService.submit(
            { builder in
                try builder.adding(call: call)
            },
            signer: signingWrapper,
            runningIn: .main,
            completion: { [weak self] result in
                switch result {
                case .success:
                    self?.presenter?.didSubmit()
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
