import Foundation
import Operation_iOS

struct PayCardHook {
    let script: DAppBrowserScript?
    let messageNames: Set<String>
    let handlers: [PayCardMessageHandling]
}
