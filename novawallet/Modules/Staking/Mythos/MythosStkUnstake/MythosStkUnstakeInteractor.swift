import Foundation
import SubstrateSdk
import Operation_iOS

class MythosStkUnstakeInteractor: AnyProviderAutoCleaning {
    weak var basePresenter: MythosStkUnstakeInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: ChainAccountResponse
    let stakingDetailsService: MythosStakingDetailsSyncServiceProtocol
    let claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingDurationFactory: MythosStkDurationOperationFactoryProtocol
    let blocktimeEstimationService: BlockTimeEstimationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: ChainAccountResponse,
        stakingDetailsService: MythosStakingDetailsSyncServiceProtocol,
        claimableRewardsService: MythosStakingClaimableRewardsServiceProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: MythosStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingDetailsService = stakingDetailsService
        self.claimableRewardsService = claimableRewardsService
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.connection = connection
        self.stakingDurationFactory = stakingDurationFactory
        self.blocktimeEstimationService = blocktimeEstimationService
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger

        self.currencyManager = currencyManager
    }

    func getExtrinsicBuilderClosure(for model: MythosStkUnstakeModel) -> ExtrinsicBuilderClosure {
        { builder in
            let unstakeCall = MythosStakingPallet.UnstakeCall(account: model.collator)
            let unlockCall = MythosStakingPallet.UnlockCall(maybeAmount: model.amount)

            return try builder
                .adding(call: unstakeCall.runtimeCall())
                .adding(call: unlockCall.runtimeCall())
        }
    }

    func onSetup() {}
}

private extension MythosStkUnstakeInteractor {
    func makeAssetBalanceSubscription() {
        clear(streamableProvider: &balanceProvider)

        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )
    }

    func makePriceSubscription() {
        clear(streamableProvider: &priceProvider)

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func makeStakingDetailsSubscription() {
        stakingDetailsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.basePresenter?.didReceiveStakingDetails(newState)
        }
    }

    func makeClaimableRewardsSubscription() {
        claimableRewardsService.add(
            observer: self,
            sendStateOnSubscription: true,
            queue: .main
        ) { [weak self] _, newState in
            self?.basePresenter?.didReceiveClaimableRewards(newState)
        }
    }

    func provideStakingDuration() {
        let wrapper = stakingDurationFactory.createDurationOperation(
            for: chainAsset.chain.chainId,
            blockTimeEstimationService: blocktimeEstimationService
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(duration):
                self?.basePresenter?.didReceiveStakingDuration(duration)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.stakingDurationFailed(error))
            }
        }
    }
}

extension MythosStkUnstakeInteractor: MythosStkUnstakeInteractorInputProtocol {
    func setup() {
        makeAssetBalanceSubscription()
        makePriceSubscription()
        makeStakingDetailsSubscription()
        makeClaimableRewardsSubscription()
        provideStakingDuration()

        onSetup()
    }

    func estimateFee(for model: MythosStkUnstakeModel) {
        let builderClosure = getExtrinsicBuilderClosure(for: model)

        extrinsicService.estimateFee(
            builderClosure,
            runningIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(fee):
                self?.basePresenter?.didReceiveFee(fee)
            case let .failure(error):
                self?.basePresenter?.didReceiveBaseError(.feeFailed(error))
            }
        }
    }

    func retryStakingDuration() {
        provideStakingDuration()
    }
}

extension MythosStkUnstakeInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAssetBalance(
        result: Result<AssetBalance?, Error>,
        accountId _: AccountId,
        chainId _: ChainModel.Id,
        assetId _: AssetModel.Id
    ) {
        switch result {
        case let .success(balance):
            basePresenter?.didReceiveBalance(balance)
        case let .failure(error):
            logger.error("Balance subscription failed: \(error)")
        }
    }
}

extension MythosStkUnstakeInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceivePrice(priceData)
        case let .failure(error):
            logger.error("Price subscription failed: \(error)")
        }
    }
}

extension MythosStkUnstakeInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil else {
            return
        }

        makePriceSubscription()
    }
}
