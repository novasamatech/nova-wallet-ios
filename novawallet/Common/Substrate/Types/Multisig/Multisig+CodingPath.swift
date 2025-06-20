import Foundation

extension Multisig {
    static var multisigList: StorageCodingPath {
        .init(moduleName: Multisig.name, itemName: "Multisigs")
    }

    static var newMultisig: StorageCodingPath {
        .init(moduleName: Multisig.name, itemName: "NewMultisig")
    }
}
