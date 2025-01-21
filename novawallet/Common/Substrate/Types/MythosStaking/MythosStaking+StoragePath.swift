import Foundation
import SubstrateSdk

extension MythosStakingPallet {
    static var userStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "UserStake")
    }
}
