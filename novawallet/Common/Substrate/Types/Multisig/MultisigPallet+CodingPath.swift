extension MultisigPallet {
    static var multisigListStoragePath: StorageCodingPath {
        .init(moduleName: MultisigPallet.name, itemName: "Multisigs")
    }

    static var newMultisigStoragePath: StorageCodingPath {
        .init(moduleName: MultisigPallet.name, itemName: "NewMultisig")
    }
}

extension MultisigPallet {
    static var multisigsAsMultiCallPath: CallCodingPath {
        .init(moduleName: MultisigPallet.name, callName: "as_multi")
    }
}

extension MultisigPallet {
    static var depositBase: ConstantCodingPath {
        .init(moduleName: MultisigPallet.name, constantName: "DepositBase")
    }

    static var depositFactor: ConstantCodingPath {
        .init(moduleName: MultisigPallet.name, constantName: "DepositFactor")
    }
}

extension MultisigPallet {
    static var newMultisigEventPath: EventCodingPath {
        .init(moduleName: MultisigPallet.name, eventName: "NewMultisig")
    }

    static var multisigApprovalEventPath: EventCodingPath {
        .init(moduleName: MultisigPallet.name, eventName: "MultisigApproval")
    }
}
