import Foundation
import SubstrateSdk

protocol ChainConnection: JSONRPCEngine & ConnectionAutobalancing & ConnectionStateReporting {
    func connect()
    func disconnect(_ force: Bool)
}

extension WebSocketEngine: ChainConnection {
    func connect() {
        connectIfNeeded()
    }

    func disconnect(_ force: Bool) {
        disconnectIfNeeded(force)
    }
}
