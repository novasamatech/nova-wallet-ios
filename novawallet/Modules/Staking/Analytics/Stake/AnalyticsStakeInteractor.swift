import RobinHood
import BigInt

final class AnalyticsStakeInteractor {
    weak var presenter: AnalyticsStakeInteractorOutputProtocol!

    let selectedAccountAddress: AccountAddress
    let chainAsset: ChainAsset
    let stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationManager: OperationManagerProtocol

    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var stashItemProvider: StreamableProvider<StashItem>?

    init(
        selectedAccountAddress: AccountAddress,
        chainAsset: ChainAsset,
        stakingLocalSubscriptionFactory: StakingLocalSubscriptionFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.selectedAccountAddress = selectedAccountAddress
        self.chainAsset = chainAsset
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationManager = operationManager
    }
}

extension AnalyticsStakeInteractor: StakingLocalStorageSubscriber, StakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        presenter.didReceiveStashItem(result: result)
    }
}

extension AnalyticsStakeInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension AnalyticsStakeInteractor: AnalyticsStakeInteractorInputProtocol {
    func setup() {
        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        } else {
            presenter.didReceivePriceData(result: .success(nil))
        }

        stashItemProvider = subscribeStashItemProvider(for: selectedAccountAddress)
    }

    func fetchStakeHistory(stashAddress: AccountAddress) {
        guard let analyticsURL = chainAsset.chain.externalApi?.staking?.url else { return }
        let subqueryStakeHistorySource = SubqueryStakeSource(address: stashAddress, url: analyticsURL)
        let fetchOperation = subqueryStakeHistorySource.fetchOperation()

        fetchOperation.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let response = try fetchOperation.targetOperation.extractNoCancellableResultData() ?? []
                    self?.presenter.didReceieve(stakeDataResult: .success(response))
                } catch {
                    self?.presenter.didReceieve(stakeDataResult: .failure(error))
                }
            }
        }
        operationManager.enqueue(operations: fetchOperation.allOperations, in: .transient)
    }
}
