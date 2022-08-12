import UIKit
import RobinHood
import BigInt
import SubstrateSdk

class ParaStkBaseUnstakeInteractor {
    weak var basePresenter: ParaStkBaseUnstakeInteractorOutputProtocol?

    let chainAsset: ChainAsset
    let selectedAccount: MetaChainAccountResponse
    let walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let extrinsicService: ExtrinsicServiceProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let repositoryFactory: SubstrateRepositoryFactoryProtocol
    let connection: JSONRPCEngine
    let runtimeProvider: RuntimeCodingServiceProtocol
    let stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol
    let stakingDurationFactory: ParaStkDurationOperationFactoryProtocol
    let blocktimeEstimationService: BlockTimeEstimationServiceProtocol
    let operationQueue: OperationQueue

    private var balanceProvider: StreamableProvider<AssetBalance>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var delegatorProvider: AnyDataProvider<ParachainStaking.DecodedDelegator>?
    private var schduledRequestsProvider: StreamableProvider<ParachainStaking.MappedScheduledRequest>?

    init(
        chainAsset: ChainAsset,
        selectedAccount: MetaChainAccountResponse,
        stakingLocalSubscriptionFactory: ParachainStakingLocalSubscriptionFactoryProtocol,
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        extrinsicService: ExtrinsicServiceProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        connection: JSONRPCEngine,
        runtimeProvider: RuntimeCodingServiceProtocol,
        stakingDurationFactory: ParaStkDurationOperationFactoryProtocol,
        blocktimeEstimationService: BlockTimeEstimationServiceProtocol,
        repositoryFactory: SubstrateRepositoryFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.extrinsicService = extrinsicService
        self.feeProxy = feeProxy
        self.connection = connection
        self.stakingDurationFactory = stakingDurationFactory
        self.blocktimeEstimationService = blocktimeEstimationService
        self.runtimeProvider = runtimeProvider
        self.repositoryFactory = repositoryFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func subscribeAssetBalanceAndPrice() {
        balanceProvider = subscribeToAssetBalanceProvider(
            for: selectedAccount.chainAccount.accountId,
            chainId: chainAsset.chain.chainId,
            assetId: chainAsset.asset.assetId
        )

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    private func subscribeDelegator() {
        delegatorProvider = subscribeToDelegatorState(
            for: chainAsset.chain.chainId,
            accountId: selectedAccount.chainAccount.accountId
        )
    }

    private func subscribeScheduledRequests() {
        schduledRequestsProvider = subscribeToScheduledRequests(
            for: chainAsset.chain.chainId,
            delegatorId: selectedAccount.chainAccount.accountId
        )
    }

    private func provideStakingDuration() {
        let wrapper = stakingDurationFactory.createDurationOperation(
            from: runtimeProvider,
            blockTimeEstimationService: blocktimeEstimationService
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let duration = try wrapper.targetOperation.extractNoCancellableResultData()

                    self?.basePresenter?.didReceiveStakingDuration(duration)
                } catch {
                    self?.basePresenter?.didReceiveError(error)
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }

    func setup() {
        subscribeAssetBalanceAndPrice()
        subscribeDelegator()
        subscribeScheduledRequests()

        feeProxy.delegate = self

        provideStakingDuration()
    }
}

extension ParaStkBaseUnstakeInteractor: ParaStkBaseUnstakeInteractorInputProtocol {
    func estimateFee(for callWrapper: UnstakeCallWrapper) {
        feeProxy.estimateFee(
            using: extrinsicService,
            reuseIdentifier: callWrapper.extrinsicId()
        ) { builder in
            try callWrapper.accept(builder: builder)
        }
    }
}

extension ParaStkBaseUnstakeInteractor: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
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
            basePresenter?.didReceiveError(error)
        }
    }
}

extension ParaStkBaseUnstakeInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(priceData):
            basePresenter?.didReceivePrice(priceData)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}

extension ParaStkBaseUnstakeInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        basePresenter?.didReceiveFee(result)
    }
}

extension ParaStkBaseUnstakeInteractor: ParastakingLocalStorageSubscriber, ParastakingLocalStorageHandler {
    func handleParastakingDelegatorState(
        result: Result<ParachainStaking.Delegator?, Error>,
        for _: ChainModel.Id,
        accountId _: AccountId
    ) {
        switch result {
        case let .success(delegator):
            basePresenter?.didReceiveDelegator(delegator)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }

    func handleParastakingScheduledRequests(
        result: Result<[ParachainStaking.DelegatorScheduledRequest]?, Error>,
        for _: ChainModel.Id,
        delegatorId _: AccountId
    ) {
        switch result {
        case let .success(scheduledRequests):
            basePresenter?.didReceiveScheduledRequests(scheduledRequests)
        case let .failure(error):
            basePresenter?.didReceiveError(error)
        }
    }
}

extension ParaStkBaseUnstakeInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard basePresenter != nil, let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
