import UIKit
import Operation_iOS

final class MythosStkClaimRewardsInteractor: AnyProviderAutoCleaning, RuntimeConstantFetching {
    weak var presenter: MythosStkClaimRewardsInteractorOutputProtocol?

    let selectedAccount: MetaChainAccountResponse
    let chainAsset: ChainAsset
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol
    let signingWrapper: SigningWrapperProtocol
    let logger: LoggerProtocol
    let operationQueue: OperationQueue

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let rewardsSyncService: MythosStakingClaimableRewardsServiceProtocol

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
        feeProxy: ExtrinsicFeeProxyProtocol,
        submissionMonitor: ExtrinsicSubmitMonitorFactoryProtocol,
        signingWrapper: SigningWrapperProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        rewardsSyncService: MythosStakingClaimableRewardsServiceProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.selectedAccount = selectedAccount
        self.chainAsset = chainAsset
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.submissionMonitor = submissionMonitor
        self.signingWrapper = signingWrapper
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.rewardsSyncService = rewardsSyncService
        self.logger = logger
        self.operationQueue = operationQueue

        self.currencyManager = currencyManager
    }
}

private extension MythosStkClaimRewardsInteractor {
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

    func makeClaimableRewardsSubscription() {
        rewardsSyncService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            if let newState {
                self?.presenter?.didReceiveClaimableRewards(newState)
            }
        }
    }

    func getExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure {
        { builder in
            try builder.adding(call: MythosStakingPallet.ClaimRewardsCall().runtimeCall())
        }
    }
}

extension MythosStkClaimRewardsInteractor: MythosStkClaimRewardsInteractorInputProtocol {
    func setup() {
        feeProxy.delegate = self

        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeClaimableRewardsSubscription()
    }

    func estimateFee() {
        let closure = getExtrinsicBuilderClosure()

        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: "claim",
            payingIn: nil,
            setupBy: closure
        )
    }

    func submit() {
        let closure = getExtrinsicBuilderClosure()

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
                let txHash = try result.getSuccessExtrinsicStatus().extrinsicHash
                self?.presenter?.didReceiveSubmissionResult(.success(txHash))
            } catch {
                self?.presenter?.didReceiveSubmissionResult(.failure(error))
            }
        }
    }
}

extension MythosStkClaimRewardsInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<ExtrinsicFeeProtocol, Error>, for _: TransactionFeeId) {
        presenter?.didReceiveFeeResult(result)
    }
}

extension MythosStkClaimRewardsInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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

extension MythosStkClaimRewardsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            presenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription: \(error)")
        }
    }
}

extension MythosStkClaimRewardsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
