import UIKit
import Operation_iOS

final class CrowdloanUnlockInteractor: AnyProviderAutoCleaning, RuntimeConstantFetching {
    weak var presenter: CrowdloanUnlockInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let signingWrapper: SigningWrapperProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    var accountId: AccountId { selectedAccount.chainAccount.accountId }
    var chainId: ChainModel.Id { chainAsset.chain.chainId }
    var asset: AssetModel { chainAsset.asset }
    var assetId: AssetModel.Id { asset.assetId }

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        selectedAccount: MetaChainAccountResponse,
        chainAsset: ChainAsset,
        extrinsicService: ExtrinsicServiceProtocol,
        submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.submissionMonitor = submissionMonitor
        self.signingWrapper = signingWrapper
        self.runtimeService = runtimeService
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.logger = logger
        self.operationQueue = operationQueue

        self.currencyManager = currencyManager
    }
}

private extension CrowdloanUnlockInteractor {
    func setupDataRetrieval() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        provideExistentialDeposit()
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

    func getExtrinsicBuilderClosure(for items: Set<CrowdloanUnlockItem>) -> ExtrinsicBuilderClosure {
        { builder in
            try items.reduce(builder) { builder, item in
                let call = AhOpsPallet.WithdrawCrowdloanContributionCall(
                    block: item.block,
                    paraId: item.paraId
                )

                return try builder.adding(call: call.runtimeCall())
            }.with(batchType: .ignoreFails)
        }
    }

    func provideExistentialDeposit() {
        fetchConstant(
            for: .existentialDeposit,
            runtimeCodingService: runtimeService,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<Balance, Error>) in
            switch result {
            case let .success(existentialDeposit):
                self?.presenter?.didReceiveExistentialDeposit(existentialDeposit)
            case let .failure(error):
                self?.logger.error("Unexpected ed error: \(error)")
            }
        }
    }
}

extension CrowdloanUnlockInteractor: CrowdloanUnlockInteractorInputProtocol {
    func setup() {
        setupDataRetrieval()
    }

    func estimateFee(for unlocks: Set<CrowdloanUnlockItem>) {
        let closure = getExtrinsicBuilderClosure(for: unlocks)

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            self?.presenter?.didReceiveFeeResult(result)
        }
    }

    func submit(unlocks: Set<CrowdloanUnlockItem>) {
        let closure = getExtrinsicBuilderClosure(for: unlocks)

        let wrapper = submissionMonitor.submitAndMonitorWrapper(
            extrinsicBuilderClosure: closure,
            signer: signingWrapper
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            do {
                let model = try result.getSuccessSubmittedModel()
                self?.presenter?.didReceiveSubmissionResult(.success(model))
            } catch {
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}

extension CrowdloanUnlockInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension CrowdloanUnlockInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription: \(error)")
        }
    }
}

extension CrowdloanUnlockInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
