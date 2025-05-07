import Foundation
import Operation_iOS

protocol RaiseLocalStorageSubscriber: AnyObject, LocalStorageProviderObserving {
    var raiseProviderFactory: RaiseProviderFactoryProtocol { get }

    var raiseLocalSubscriptionHandler: RaiseLocalSubscriptionHandler { get }

    func subscribeRaiseCards() -> AnyDataProvider<RaiseCardLocal>
}

extension RaiseLocalStorageSubscriber {
    func subscribeRaiseCards() -> AnyDataProvider<RaiseCardLocal> {
        let provider = raiseProviderFactory.createCardsProvider()

        provider.addObserver(
            self,
            deliverOn: .main,
            executing: { [weak self] changes in
                self?.raiseLocalSubscriptionHandler.handleRaiseCards(result: .success(changes))
            },
            failing: { [weak self] error in
                self?.raiseLocalSubscriptionHandler.handleRaiseCards(result: .failure(error))
            }
        )

        return provider
    }
}

extension RaiseLocalStorageSubscriber where Self: RaiseLocalSubscriptionHandler {
    var raiseLocalSubscriptionHandler: RaiseLocalSubscriptionHandler { self }
}
