import Foundation
import SubstrateSdk

protocol ChainConnection: JSONRPCEngine & ConnectionAutobalancing & ConnectionStateReporting {
    func connect()
    func disconnect()
}

extension WebSocketEngine: ChainConnection {
    func connect() {
        connectIfNeeded()
    }

    func disconnect() {
        disconnectIfNeeded()
    }
}
