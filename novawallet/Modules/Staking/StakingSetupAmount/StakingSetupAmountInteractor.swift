import UIKit
import RobinHood
import BigInt

final class StakingSetupAmountInteractor: AnyProviderAutoCleaning {
    weak var presenter: StakingSetupAmountInteractorOutputProtocol?

    let selectedChainAsset: ChainAsset
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol

    private lazy var operationManager = OperationManager(operationQueue: operationQueue)
    private(set) var priceProvider: StreamableProvider<PriceData>?
    private(set) var balanceProvider: StreamableProvider<AssetBalance>?
    private(set) var selectedAccount: ChainAccountResponse
    private(set) var operationQueue: OperationQueue

    init(
        selectedAccount: ChainAccountResponse,
        selectedChainAsset: ChainAsset,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.selectedAccount = selectedAccount
        self.selectedChainAsset = selectedChainAsset
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.runtimeProvider = runtimeProvider
        self.extrinsicService = extrinsicService
        self.operationQueue = operationQueue

        self.currencyManager = currencyManager
    }

    deinit {
        clear(streamableProvider: &priceProvider)
        clear(streamableProvider: &balanceProvider)
    }

    private func performPriceSubscription() {
        clear(streamableProvider: &priceProvider)

        guard let priceId = selectedChainAsset.asset.priceId else {
            presenter?.didReceive(price: nil)
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func performAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        let chainAssetId = selectedChainAsset.chainAssetId

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAssetId.chainId,
            assetId: chainAssetId.assetId
        )
    }

    private func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        coderFactory: RuntimeCoderFactoryProtocol
    ) {
        guard let accountAddress = rewardDestination.accountAddress else {
            return
        }

        let closure: ExtrinsicBuilderClosure = { builder in
            let controller = try address.toAccountId()
            let payee = try Staking.RewardDestinationArg(rewardDestination: accountAddress)

            let bondClosure = try Staking.Bond.appendCall(
                for: .accoundId(controller),
                value: amount,
                payee: payee,
                codingFactory: coderFactory
            )

            let callFactory = SubstrateCallFactory()

            let targets = Array(
                repeating: SelectedValidatorInfo(address: address),
                count: SubstrateConstants.maxNominations
            )
            let nominateCall = try callFactory.nominate(targets: targets)

            return try bondClosure(builder).adding(call: nominateCall)
        }

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceive(paymentInfo: info)
            case let .failure(error):
                self?.presenter?.didReceive(error: .fee(error))
            }
        }
    }
}

extension StakingSetupAmountInteractor: StakingSetupAmountInteractorInputProtocol {
    func setup() {
        performAssetBalanceSubscription()
        performPriceSubscription()
    }

    func remakeSubscriptions() {
        performAssetBalanceSubscription()
        performPriceSubscription()
    }

    func estimateFee(
        for address: String,
        amount: BigUInt,
        rewardDestination: RewardDestination<ChainAccountResponse>
    ) {
        runtimeProvider.fetchCoderFactory(
            runningIn: operationManager,
            completion: { [weak self] coderFactory in
                self?.estimateFee(
                    for: address,
                    amount: amount,
                    rewardDestination: rewardDestination,
                    coderFactory: coderFactory
                )
            }, errorClosure: { [weak self] error in
                self?.presenter?.didReceive(error: .fetchCoderFactory(error))
            }
        )
    }
}

extension StakingSetupAmountInteractor: WalletLocalStorageSubscriber,
    WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id,
        assetId: AssetModel.Id
    ) {
        guard
            chainId == selectedChainAsset.chain.chainId,
            assetId == selectedChainAsset.asset.assetId,
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
        if selectedChainAsset.asset.priceId == priceId {
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
              let priceId = selectedChainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
