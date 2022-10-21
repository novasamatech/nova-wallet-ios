import UIKit
import SubstrateSdk

final class ReferendumFullDetailsInteractor {
    weak var presenter: ReferendumFullDetailsInteractorOutputProtocol?
    let chain: ChainModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let currencyManager: CurrencyManagerProtocol
    let operationQueue: OperationQueue
    let processingOperationFactory: PrettyPrintedJSONOperationFactoryProtocol
    let referendumAction: ReferendumActionLocal

    private var priceProvider: AnySingleValueProvider<PriceData>?

    init(
        chain: ChainModel,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        currencyManager: CurrencyManagerProtocol,
        processingOperationFactory: PrettyPrintedJSONOperationFactoryProtocol,
        referendumAction: ReferendumActionLocal,
        operationQueue: OperationQueue
    ) {
        self.processingOperationFactory = processingOperationFactory
        self.chain = chain
        self.referendumAction = referendumAction
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.operationQueue = operationQueue
        self.currencyManager = currencyManager
    }

    private func makeSubscriptions() {
        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func formatJSON() {
        guard let call = referendumAction.call else {
            presenter?.didReceive(error: .emptyJSON)
            return
        }
        let processingOperation = processingOperationFactory.createProcessingOperation(for: call.args)
        processingOperation.completionBlock = { [weak self] in
            guard let self = self else {
                return
            }
            do {
                let result = try processingOperation.extractNoCancellableResultData()
                DispatchQueue.main.async {
                    self.presenter?.didReceive(json: result)
                }
            } catch {
                DispatchQueue.main.async {
                    self.presenter?.didReceive(json: nil)
                    self.presenter?.didReceive(error: .processingJSON(error))
                }
            }
        }

        operationQueue.addOperation(processingOperation)
    }
}

extension ReferendumFullDetailsInteractor: ReferendumFullDetailsInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
        formatJSON()
    }
}

extension ReferendumFullDetailsInteractor: PriceLocalSubscriptionHandler, PriceLocalStorageSubscriber {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            presenter?.didReceive(price: price)
        case let .failure(error):
            presenter?.didReceive(error: .priceFailed(error))
        }
    }
}

extension ReferendumFullDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            if let priceId = chain.utilityAsset()?.priceId {
                priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
            }
        }
    }
}
