import Foundation
import SubstrateSdk

struct EventCodingPath: Equatable {
    let moduleName: String
    let eventName: String

    init(moduleName: String, eventName: String) {
        self.moduleName = moduleName
        self.eventName = eventName
    }
}

extension EventCodingPath {
    static var extrisicSuccess: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicSuccess")
    }

    static var extrinsicFailed: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicFailed")
    }

    static var balancesDeposit: EventCodingPath {
        EventCodingPath(moduleName: "Balances", eventName: "Deposit")
    }

    static var treasuryDeposit: EventCodingPath {
        EventCodingPath(moduleName: "Treasury", eventName: "Deposit")
    }

    static var balancesWithdraw: EventCodingPath {
        EventCodingPath(moduleName: "Balances", eventName: "Withdraw")
    }

    static var balancesTransfer: EventCodingPath {
        EventCodingPath(moduleName: "Balances", eventName: "Transfer")
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
