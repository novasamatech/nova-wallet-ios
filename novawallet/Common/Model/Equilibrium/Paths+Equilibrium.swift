import Foundation

extension StorageCodingPath {
    static var equilibriumBalances: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Account")
    }

    static var equilibriumLocks: StorageCodingPath {
        StorageCodingPath(moduleName: "EqBalances", itemName: "Locked")
    }

    static var equilibriumReserved: StorageCodingPath {
        StorageCodingPath(moduleName: "EqBalances", itemName: "Reserved")
    }
}

extension CallCodingPath {
    static var equilibriumTransfer: CallCodingPath {
        CallCodingPath(moduleName: "EqBalances", callName: "transfer")
    }

    var isEquilibriumTransfer: Bool {
        self == .equilibriumTransfer
    }
}

extension ConstantCodingPath {
    static var equilibriumExistentialDepositBasic: ConstantCodingPath {
        ConstantCodingPath(moduleName: "EqBalances", constantName: "ExistentialDepositBasic")
    }
}
