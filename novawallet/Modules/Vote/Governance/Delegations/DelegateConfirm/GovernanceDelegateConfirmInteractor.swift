import UIKit
import SubstrateSdk
import Operation_iOS

final class GovernanceDelegateConfirmInteractor: GovernanceDelegateInteractor {
    var presenter: GovernanceDelegateConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? GovernanceDelegateConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?

    init(
        selectedAccount: MetaChainAccountResponse,
        chain: ChainModel,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        referendumsSubscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        timelineService: ChainTimelineFacadeProtocol,
        chainRegistry: ChainRegistryProtocol,
        currencyManager: CurrencyManagerProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: MultiExtrinsicFeeProxyProtocol,
        signer: SigningWrapperProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.signer = signer

        super.init(
            selectedAccount: selectedAccount,
            chain: chain,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            referendumsSubscriptionFactory: referendumsSubscriptionFactory,
            walletLocalSubscriptionFactory: walletLocalSubscriptionFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            timelineService: timelineService,
            chainRegistry: chainRegistry,
            currencyManager: currencyManager,
            extrinsicFactory: extrinsicFactory,
            extrinsicService: extrinsicService,
            feeProxy: feeProxy,
            lockStateFactory: lockStateFactory,
            operationQueue: operationQueue
        )
    }

    private func clearAndSubscribeLocks() {
        locksSubscription?.removeObserver(self)
        locksSubscription = nil

        guard let asset = chain.utilityAsset() else {
            return
        }

        locksSubscription = subscribeToLocksProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: asset.assetId
        )
    }

    override func setup() {
        super.setup()

        clearAndSubscribeLocks()
    }

    override func remakeSubscriptions() {
        super.remakeSubscriptions()

        clearAndSubscribeLocks()
    }

    override func handleAccountLocks(
        result: Result<[DataProviderChange<AssetLock>], Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            let locks = changes.mergeToDict([:]).values
            presenter?.didReceiveLocks(Array(locks))
        case let .failure(error):
            presenter?.didReceiveError(.locksSubscriptionFailed(error))
        }
    }

    func handleMultiExtrinsicSubmission(result: SubmitIndexedExtrinsicResult) {
        presenter?.didReceiveSubmissionResult(result)
    }
}

extension GovernanceDelegateConfirmInteractor: GovernanceDelegateConfirmInteractorInputProtocol {
    func submit(actions: [GovernanceDelegatorAction]) {
        do {
            let splitter = try createExtrinsicSplitter(for: actions)

            extrinsicService.submitWithTxSplitter(
                splitter,
                signer: signer,
                runningIn: .main
            ) { [weak self] result in
                self?.handleMultiExtrinsicSubmission(result: result)
            }
        } catch {
            presenter?.didReceiveError(.submitFailed(error))
        }
    }
}
