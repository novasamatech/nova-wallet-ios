import UIKit
import SubstrateSdk
import Operation_iOS

final class ReferendumFullDetailsInteractor: AnyProviderAutoCleaning {
    weak var presenter: ReferendumFullDetailsInteractorOutputProtocol?
    let chain: ChainModel
    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let operationQueue: OperationQueue
    let processingOperationFactory: PrettyPrintedJSONOperationFactoryProtocol
    let referendumAction: ReferendumActionLocal

    private var utilityPriceProvider: StreamableProvider<PriceData>?
    private var actionPriceProvider: StreamableProvider<PriceData>?

    var utilityAssetPriceId: AssetModel.PriceId? {
        chain.utilityAsset()?.priceId
    }

    var actionAssetPriceId: AssetModel.PriceId? {
        referendumAction.requestedAmount()?.otherChainAssetOrCurrentUtility(
            from: chain
        )?.asset.priceId
    }

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

    private func updateUtilityPriceSubscription() {
        clear(streamableProvider: &utilityPriceProvider)

        guard let priceId = utilityAssetPriceId else {
            return
        }

        utilityPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func updateActionPriceSubscription() {
        clear(streamableProvider: &actionPriceProvider)

        guard let priceId = actionAssetPriceId, priceId != utilityAssetPriceId else {
            return
        }

        actionPriceProvider = subscribeToPrice(for: priceId, currency: selectedCurrency)
    }

    private func makeSubscriptions() {
        updateUtilityPriceSubscription()
        updateActionPriceSubscription()
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
    func handlePrice(result: Result<PriceData?, Error>, priceId: AssetModel.PriceId) {
        switch result {
        case let .success(price):
            if priceId == utilityAssetPriceId {
                presenter?.didReceiveUtilityAsset(price: price)
            }

            if priceId == actionAssetPriceId {
                presenter?.didReceiveRequestedAmount(price: price)
            }

        case let .failure(error):
            presenter?.didReceive(error: .priceFailed(error))
        }
    }
}

extension ReferendumFullDetailsInteractor: SelectedCurrencyDepending {
    func applyCurrency() {
        if presenter != nil {
            updateUtilityPriceSubscription()
            updateActionPriceSubscription()
        }
    }
}
