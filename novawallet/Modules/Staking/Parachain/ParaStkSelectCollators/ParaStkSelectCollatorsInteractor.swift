import UIKit

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

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chainAsset: ChainAsset,
        collatorService: ParachainStakingCollatorServiceProtocol,
        rewardService: ParaStakingRewardCalculatorServiceProtocol,
        connection: ChainConnection,
        runtimeProvider: RuntimeProviderProtocol,
        collatorOperationFactory: ParaStkCollatorsOperationFactoryProtocol,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
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
            priceProvider = subscribeToPrice(for: priceId)
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
