import UIKit
import SubstrateSdk
import RobinHood
import BigInt

final class GovernanceUnlockConfirmInteractor: GovernanceUnlockInteractor, AnyProviderAutoCleaning {
    var presenter: GovernanceUnlockConfirmInteractorOutputProtocol? {
        get {
            basePresenter as? GovernanceUnlockConfirmInteractorOutputProtocol
        }

        set {
            basePresenter = newValue
        }
    }

    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let extrinsicFactory: GovernanceExtrinsicFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let signer: SigningWrapperProtocol

    private var locksSubscription: StreamableProvider<AssetLock>?
    private var assetBalanceProvider: StreamableProvider<AssetBalance>?

    init(
        chain: ChainModel,
        selectedAccount: MetaChainAccountResponse,
        subscriptionFactory: GovernanceSubscriptionFactoryProtocol,
        lockStateFactory: GovernanceLockStateFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        extrinsicFactory: GovernanceExtrinsicFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        signer: SigningWrapperProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        generalLocalSubscriptionFactory: GeneralStorageSubscriptionFactoryProtocol,
        blockTimeService: BlockTimeEstimationServiceProtocol,
        blockTimeFactory: BlockTimeOperationFactoryProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeProviderProtocol,
        operationQueue: OperationQueue,
        currencyManager: CurrencyManagerProtocol
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.extrinsicFactory = extrinsicFactory
        self.extrinsicService = extrinsicService
        self.signer = signer

        super.init(
            chain: chain,
            selectedAccount: selectedAccount,
            subscriptionFactory: subscriptionFactory,
            lockStateFactory: lockStateFactory,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            generalLocalSubscriptionFactory: generalLocalSubscriptionFactory,
            blockTimeService: blockTimeService,
            blockTimeFactory: blockTimeFactory,
            connection: connection,
            runtimeProvider: runtimeProvider,
            operationQueue: operationQueue,
            currencyManager: currencyManager
        )
    }

    private func clearAndSubscribeLocks() {
        clear(streamableProvider: &locksSubscription)

        guard let assetId = chain.utilityAsset()?.assetId else {
            return
        }

        locksSubscription = subscribeToLocksProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: assetId
        )
    }

    private func clearAndSubscribeBalance() {
        clear(streamableProvider: &assetBalanceProvider)

        guard let assetId = chain.utilityAsset()?.assetId else {
            return
        }

        assetBalanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chain.chainId,
            assetId: assetId
        )
    }

    private func createExtrinsicBuilderClosure(
        for actions: Set<GovernanceUnlockSchedule.Action>
    ) -> ExtrinsicBuilderClosure {
        { [weak self] builder in
            guard let strongSelf = self else {
                return builder
            }

            return try strongSelf.extrinsicFactory.unlock(
                with: actions,
                accountId: strongSelf.selectedAccount.chainAccount.accountId,
                builder: builder
            )
        }
    }

    private func makeSubscription() {
        clearAndSubscribeBalance()
        clearAndSubscribeLocks()
    }

    override func setup() {
        super.setup()

        makeSubscription()
    }

    override func remakeSubscriptions() {
        super.remakeSubscriptions()

        makeSubscription()
    }
}

extension GovernanceUnlockConfirmInteractor: GovernanceUnlockConfirmInteractorInputProtocol {
    func estimateFee(for actions: Set<GovernanceUnlockSchedule.Action>) {
        let closure = createExtrinsicBuilderClosure(for: actions)

        extrinsicService.estimateFee(closure, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(feeInfo):
                self?.presenter?.didReceiveFee(feeInfo)
            case let .failure(error):
                self?.presenter?.didReceiveError(.feeFetchFailed(error))
            }
        }
    }

    func unlock(using actions: Set<GovernanceUnlockSchedule.Action>) {
        let closure = createExtrinsicBuilderClosure(for: actions)

        extrinsicService.submit(closure, signer: signer, runningIn: .main) { [weak self] result in
            switch result {
            case let .success(hashString):
                self?.presenter?.didReceiveUnlockHash(hashString)
            case let .failure(error):
                self?.presenter?.didReceiveError(.unlockFailed(error))
            }
        }
    }
}

extension GovernanceUnlockConfirmInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountLocks(
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

    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(changes):
            presenter?.didReceiveBalance(changes)
        case let .failure(error):
            presenter?.didReceiveError(.balanceSubscriptionFailed(error))
        }
    }
}
