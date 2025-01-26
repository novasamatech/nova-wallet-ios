import UIKit
import SubstrateSdk
import Operation_iOS

class MythosStakingBaseInteractor: RuntimeConstantFetching {
    weak var basePresenter: MythosStakingBaseInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let frozenBalanceStore: MythosStakingFrozenBalanceStore
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var minStakeProvider: AnyDataProvider<DecodedBigUInt>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingDetailsService = stakingDetailsService
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger

        frozenBalanceStore = MythosStakingFrozenBalanceStore(
            accountId: selectedAccount.accountId,
            chainAssetId: chainAsset.chainAssetId,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            logger: logger
        )

        self.currencyManager = currencyManager
    }

    func getExtrinsicBuilderClosure(from model: MythosStakeModel) -> ExtrinsicBuilderClosure {
        { builder in
            var resultBuilder = builder

            if model.amount.toLock > 0 {
                let lockCall = MythosStakingPallet.LockCall(amount: model.amount.toLock)
                resultBuilder = try resultBuilder.adding(call: lockCall.runtimeCall())
            }

            let stakeCall = MythosStakingPallet.StakeCall(
                targets: [
                    MythosStakingPallet.StakeTarget(
                        candidate: model.collator,
                        stake: model.amount.toStake
                    )
                ]
            )

            return try resultBuilder.adding(call: stakeCall.runtimeCall())
        }
    }

    func onSetup() {}

    func onStakingDetails(_: MythosStakingDetails?) {}
}

private extension MythosStakingBaseInteractor {
    func makeAssetBalanceSubscription() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makeFrozenBalanceSubscription() {
        frozenBalanceStore.setup()

        frozenBalanceStore.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let frozenBalance = newState {
                self?.basePresenter?.didReceiveFrozenBalance(frozenBalance)
            }
        }
    }

    func makeMinStakeSubscription() {
        minStakeProvider = subscribeToMinStake(for: chainAsset.chain.chainId)
    }

    func makePriceSubscription() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider?.removeObserver(self)

            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeStakingDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.onStakingDetails(newState)
            self?.basePresenter?.didReceiveDetails(newState)
        }
    }

    func makeBlockNumberSubscription() {
        blockNumberProvider = subscribeToBlockNumber(for: chainAsset.chain.chainId)
    }

    func provideMaxCandidatesPerStaker() {
        fetchConstant(
            for: MythosStakingPallet.maxStakedCandidatesPath,
            runtimeCodingService: runtimeProvider,
            operationManager: OperationManager(operationQueue: operationQueue)
        ) { [weak self] (result: Result<UInt32, Error>) in
            switch result {
            case let .success(maxCandidatesPerStaker):
                self?.basePresenter?.didReceiveMaxCollatorsPerStaker(maxCandidatesPerStaker)
            case let .failure(error):
                self?.logger.error("Unexpected error: \(error)")
            }
        }
    }
}

extension MythosStakingBaseInteractor: MythosStakingBaseInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeFrozenBalanceSubscription()
        makeBlockNumberSubscription()

        makeStakingDetailsSubscription()
        makeMinStakeSubscription()

        provideMaxCandidatesPerStaker()

        onSetup()
    }

    func estimateFee(with model: MythosStakeModel) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: model.reuseTxId,
            payingIn: nil,
            setupBy: getExtrinsicBuilderClosure(from: model)
        )
    }
}

extension MythosStakingBaseInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(
        result: Result<ExtrinsicFeeProtocol, Error>,
        for _: TransactionFeeId
    ) {
        switch result {
        case let .success(model):
            basePresenter?.didReceiveFee(model)
        case let .failure(error):
            basePresenter?.didReceiveBaseError(.feeFailed(error))
        }
    }
}

extension MythosStakingBaseInteractor: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleMinStake(
        result: Result<Balance?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(minStake):
            if let minStake {
                basePresenter?.didReceiveMinStakeAmount(minStake)
            }
        case let .failure(error):
            logger.error("Min stake subscription failed: \(error)")
        }
    }
}

extension MythosStakingBaseInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceiveAssetBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription failed: \(error)")
        }
    }
}

extension MythosStakingBaseInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription failed: \(error)")
        }
    }
}

extension MythosStakingBaseInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                basePresenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            logger.error("Unexpected error: \(error)")
        }
    }
}

extension MythosStakingBaseInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
