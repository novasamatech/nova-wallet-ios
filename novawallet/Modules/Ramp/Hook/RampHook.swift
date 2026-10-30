import Foundation
import Operation_iOS

struct RampHook {
    let script: DAppBrowserScript?
    let messageNames: Set<String>
    let handlers: [RampMessageHandling]
}
