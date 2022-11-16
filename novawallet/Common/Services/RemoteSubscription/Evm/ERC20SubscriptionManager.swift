import Foundation
import SubstrateSdk

final class ERC20SubscriptionManager {
    let params: ERC20BalanceSubscriptionRequest
    let connection: JSONRPCEngine

    init(params: ERC20BalanceSubscriptionRequest, connection: JSONRPCEngine) {
        self.params = params
        self.connection = connection

        subscribe()
    }

    deinit {
        unsubscribe()
    }

    private func subscribe() {

    }

    private func unsubscribe() {

    }
}

extension ERC20SubscriptionManager: EvmRemoteSubscriptionProtocol {}
