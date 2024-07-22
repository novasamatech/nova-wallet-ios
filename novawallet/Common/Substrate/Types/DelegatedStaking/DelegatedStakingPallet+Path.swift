import Foundation
import SubstrateSdk

extension DelegatedStakingPallet {
    static var delegatorsPath: StorageCodingPath {
        .init(moduleName: Self.name, itemName: "Delegators")
    }
}
