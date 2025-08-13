import Foundation
import Operation_iOS

struct PayCardHook {
    let script: DAppBrowserScript?
    let messageNames: Set<String>
    let handlers: [PayCardMessageHandling]
}

protocol PayCardHookDelegate: AnyObject {
    func didRequestTopup(from model: PayCardTopupModel)
    func didReceiveNoCard()
    func didOpenCard()
    func didFailToOpenCard()
    func didReceivePendingCardOpen()
}

protocol PayCardHookFactoryProtocol {
    func createHooks(
        using params: MercuryoCardParams,
        for delegate: PayCardHookDelegate
    ) -> [PayCardHook]
}
