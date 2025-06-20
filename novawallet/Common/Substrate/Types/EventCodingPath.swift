import Foundation
import SubstrateSdk

struct EventCodingPath: Equatable, Hashable {
    let moduleName: String
    let eventName: String

    init(moduleName: String, eventName: String) {
        self.moduleName = moduleName
        self.eventName = eventName
    }
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

    static var newMultisig: EventCodingPath {
        EventCodingPath(moduleName: "Multisig", eventName: "NewMultisig")
    }
}
