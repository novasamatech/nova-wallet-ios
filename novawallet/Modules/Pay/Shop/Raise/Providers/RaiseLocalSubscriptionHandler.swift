import Foundation
import Operation_iOS

protocol RaiseLocalSubscriptionHandler: AnyObject {
    func handleRaiseCards(result: Result<[DataProviderChange<RaiseCardLocal>], Error>)
}

extension RaiseLocalSubscriptionHandler {
    func handleRaiseCards(result _: Result<[DataProviderChange<RaiseCardLocal>], Error>) {}
}
