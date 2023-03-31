import UIKit
import RobinHood

final class ParaStkSelectCollatorsInteractor {
    weak var presenter: ParaStkSelectCollatorsInteractorOutputProtocol?

    var chain: ChainModel { chainAsset.chain }

    let chainAsset: ChainAsset
    let collatorService: ParachainStakingCollatorServiceProtocol
    let rewardService: ParaStakingRewardCalculatorServiceProtocol
    let connection: ChainConnection
    let runtimeProvider: RuntimeProviderProtocol
    let collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue

    private var priceProvider: StreamableProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        operationQueue: OperationQueue
    ) {
        self.chainAsset = chainAsset
        self.collatorService = collatorService
        self.rewardService = rewardService
        self.connection = connection
        self.runtimeProvider = runtimeProvider
        self.collatorOperationFactory = collatorOperationFactory
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func provideElectedCollatorsInfo() {
        let wrapper = collatorOperationFactory.electedCollatorsInfoOperation(
            for: collatorService,
            rewardService: rewardService,
            connection: connection,
            runtimeProvider: runtimeProvider,
            chainFormat: chain.chainFormat
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let electedCollators = try wrapper.targetOperation.extractNoCancellableResultData()
                    self?.presenter?.didReceiveCollators(result: .success(electedCollators))
                } catch {
                    self?.presenter?.didReceiveCollators(result: .failure(error))
                }
            }
        }

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
    }
}

extension ParaStkSelectCollatorsInteractor: ParaStkSelectCollatorsInteractorInputProtocol {
    func setup() {
        provideElectedCollatorsInfo()

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
        }
    }

    func refresh() {
        provideElectedCollatorsInfo()
    }
}

extension ParaStkSelectCollatorsInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(
        result: Result<PriceData?, Error>,
        priceId _: AssetModel.PriceId
    ) {
        presenter?.didReceivePrice(result: result)
    }
}

extension ParaStkSelectCollatorsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        guard presenter != nil,
              let priceId = chainAsset.asset.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }
}
