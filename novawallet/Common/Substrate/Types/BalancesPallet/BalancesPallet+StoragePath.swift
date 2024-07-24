import Foundation
import SubstrateSdk

extension BalancesPallet {
    static var holdsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Holds")
    }
}
