import UIKit
import Operation_iOS

final class MythosStakingRedeemInteractor: AnyProviderAutoCleaning {
    weak var presenter: MythosStakingRedeemInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol
    let generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol
    let frozenBalanceStore: MythosStakingFrozenBalanceStore

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?
    private var releaseQueueProvider: AnyDataProvider<MythosStakingPallet.DecodedReleaseQueue>?
    private var blockNumberProvider: AnyDataProvider<DecodedBlockNumber>?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        stakingLocalSubscriptionFactory: MythosStakingLocalSubscriptionFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.submissionMonitor = submissionMonitor
        self.signingWrapper = signingWrapper
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.generalLocalSubscriptionFactory = generalLocalSubscriptionFactory
        self.logger = logger
        self.operationQueue = operationQueue

        frozenBalanceStore = MythosStakingFrozenBalanceStore(
            accountId: selectedAccount.chainAccount.accountId,
            chainAssetId: chainAsset.chainAssetId,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            logger: logger
        )

        self.currencyManager = currencyManager
    }
}

private extension MythosStakingRedeemInteractor {
    func setupDataRetrieval() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeBlockNumberSubscription()
        makeReleaseQueueSubscription()
        setupFrozenBalanceSubscription()
    }

    func clearDataRetrieval() {
        clear(streamableProvider: &balanceProvider)
        clear(streamableProvider: &priceProvider)
        clear(dataProvider: &blockNumberProvider)
        clear(dataProvider: &releaseQueueProvider)
        clearFrozenBalanceSubscription()
    }

    func makeAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)
        balanceProvider = subscribeToAssetBalanceProvider(
            for: accountId,
            chainId: chainId,
            assetId: assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeReleaseQueueSubscription() {
        clear(dataProvider: &releaseQueueProvider)

        releaseQueueProvider = subscribeToReleaseQueue(for: chainId, accountId: accountId)
    }

    func makeBlockNumberSubscription() {
        clear(dataProvider: &blockNumberProvider)

        blockNumberProvider = subscribeToBlockNumber(for: chainId)
    }

    func clearFrozenBalanceSubscription() {
        frozenBalanceStore.throttle()
        frozenBalanceStore.remove(observer: self)
    }

    func setupFrozenBalanceSubscription() {
        frozenBalanceStore.setup()

        frozenBalanceStore.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState {
                self?.presenter?.didReceiveFrozen(newState)
            }
        }
    }

    func getExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure {
        { builder in
            try builder.adding(call: MythosStakingPallet.ReleaseCall().runtimeCall())
        }
    }
}

extension MythosStakingRedeemInteractor: MythosStakingRedeemInteractorInputProtocol {
    func setup() {
        setupDataRetrieval()
    }

    func estimateFee() {
        let closure = getExtrinsicBuilderClosure()

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.presenter?.didReceiveFeeResult(result)
        }
    }

    func submit() {
        let closure = getExtrinsicBuilderClosure()

        let wrapper = submissionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: closure,
            signer: signingWrapper
        )

        clearDataRetrieval()

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let model = try result.getSuccessSubmittedModel()
                self?.presenter?.didReceiveSubmissionResult(.success(model))
            } catch {
                self?.setupDataRetrieval()
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}

extension MythosStakingRedeemInteractor: GeneralLocalStorageSubscriber, GeneralLocalStorageHandler {
    func handleBlockNumber(
        result: Result<BlockNumber?, Error>,
        chainId _: ChainModel.Id
    ) {
        switch result {
        case let .success(blockNumber):
            if let blockNumber {
                presenter?.didReceiveBlockNumber(blockNumber)
            }
        case let .failure(error):
            logger.error("Block number subscription failed: \(error)")
        }
    }
}

extension MythosStakingRedeemInteractor: MythosStakingLocalStorageSubscriber, MythosStakingLocalStorageHandler {
    func handleReleaseQueue(
        result: Result<MythosStakingPallet.ReleaseQueue?, Error>,
        chainId _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(releaseQueue):
            presenter?.didReceiveReleaseQueue(releaseQueue)
        case let .failure(error):
            logger.error("Release queue subscription failed: \(error)")
        }
    }
}

extension MythosStakingRedeemInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(assetBalance):
            presenter?.didReceiveAssetBalance(assetBalance)
        case let .failure(error):
            logger.error("Balance subscription: \(error)")
        }
    }
}

extension MythosStakingRedeemInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription: \(error)")
        }
    }
}

extension MythosStakingRedeemInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
