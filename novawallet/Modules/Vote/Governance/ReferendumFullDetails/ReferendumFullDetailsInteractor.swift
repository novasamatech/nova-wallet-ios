import UIKit
import SubstrateSdk

final class ReferendumFullDetailsInteractor {
    weak var presenter: ReferendumFullDetailsInteractorOutputProtocol?
    let chain: ChainModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
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
        priceProvider?.removeObserver(self)
        priceProvider = nil

        guard let priceId = chain.utilityAsset()?.priceId else {
            return
        }

        priceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func formatJSON() {
        guard let wrappedCall = referendumAction.call else {
            presenter?.didReceive(call: nil)
            return
        }

        do {
            guard let json = try wrappedCall.value?.toScaleCompatibleJSON() else {
                presenter?.didReceive(call: .tooLong)
                return
            }

            let processingOperation = processingOperationFactory.createProcessingOperation(for: json)
            processingOperation.completionBlock = { [weak self] in
                DispatchQueue.main.async {
                    do {
                        let result = try processingOperation.extractNoCancellableResultData()
                        self?.presenter?.didReceive(call: .concrete(result))
                    } catch {
                        self?.presenter?.didReceive(error: .processingJSON(error))
                    }
                }
            }

            operationQueue.addOperation(processingOperation)
        } catch {
            presenter?.didReceive(error: .processingJSON(error))
        }
    }
}

extension ReferendumFullDetailsInteractor: ReferendumFullDetailsInteractorInputProtocol {
    func setup() {
        makeSubscriptions()
        formatJSON()
    }

    func remakeSubscriptions() {
        makeSubscriptions()
    }

    func refreshCall() {
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
