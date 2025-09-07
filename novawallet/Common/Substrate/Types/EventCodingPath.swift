import Foundation
import SubstrateSdk

struct EventCodingPath: Equatable, Hashable {
    let moduleName: String
    let eventName: String
}

extension EventCodingPath {
    static var treasuryDeposit: EventCodingPath {
        EventCodingPath(moduleName: "Treasury", eventName: "Deposit")
    }

    static var tokensTransfer: EventCodingPath {
        EventCodingPath(moduleName: "Tokens", eventName: "Transfer")
    }

    static var currenciesTransferred: EventCodingPath {
        EventCodingPath(moduleName: "Currencies", eventName: "Transferred")
    }

    static var ethereumExecuted: EventCodingPath {
        EventCodingPath(moduleName: "Ethereum", eventName: "Executed")
    }
}
