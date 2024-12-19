import Foundation

extension BalancesPallet {
    static var balancesDeposit: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "Deposit")
    }

    static var balancesWithdraw: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "Withdraw")
    }

    static var balancesTransfer: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "Transfer")
    }

    static var balancesMinted: EventCodingPath {
        EventCodingPath(moduleName: Self.name, eventName: "Minted")
    }
}
