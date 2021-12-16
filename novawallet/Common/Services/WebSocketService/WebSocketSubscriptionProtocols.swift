import Foundation
import IrohaCrypto
import SubstrateSdk

protocol WebSocketSubscribing {}

protocol WebSocketSubscriptionFactoryProtocol {
    func createSubscriptions(
        address: String,
        type: SNAddressType,
        engine: JSONRPCEngine
    ) throws -> [WebSocketSubscribing]
}
