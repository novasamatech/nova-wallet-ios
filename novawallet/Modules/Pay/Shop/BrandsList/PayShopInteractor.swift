import UIKit
import Operation_iOS
import Keystore_iOS

final class PayShopInteractor: PayShopBrandsInteractor, PayShopInteractorInputProtocol {
    let raiseProviderFactory: RaiseProviderFactoryProtocol
    let logger: LoggerProtocol

    var listPresenter: PayShopInteractorOutputProtocol? {
        presenter as? PayShopInteractorOutputProtocol
    }

    private var raiseCardsProvider: AnyDataProvider<RaiseCardLocal>?

    init(
        operationFactory: RaiseOperationFactoryProtocol,
        raiseProviderFactory: RaiseProviderFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.raiseProviderFactory = raiseProviderFactory
        self.logger = logger

        super.init(
            operationFactory: operationFactory,
            operationQueue: operationQueue
        )
    }

    func setup() {
        doRaiseCardsSubscription()
    }

    func refresh() {
        raiseCardsProvider?.refresh()
    }
}

private extension PayShopInteractor {
    func doRaiseCardsSubscription() {
        clear(dataProvider: &raiseCardsProvider)

        raiseCardsProvider = subscribeRaiseCards()
    }
}

extension PayShopInteractor: RaiseLocalStorageSubscriber, AnyProviderAutoCleaning {}

extension PayShopInteractor: RaiseLocalSubscriptionHandler {
    func handleRaiseCards(result: Result<[DataProviderChange<RaiseCardLocal>], Error>) {
        switch result {
        case let .success(changes):
            listPresenter?.didReceive(raiseCardsChanges: changes)
        case let .failure(error):
            listPresenter?.didReceive(error: .raiseSubscriptionFailed(error))
        }
    }
}
