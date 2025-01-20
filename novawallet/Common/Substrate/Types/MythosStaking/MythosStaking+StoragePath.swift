import Foundation
import SubstrateSdk

extension MythosStakingPallet {
    static var userStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "UserStake")
    }

    static var minStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "MinStake")
    }

    static var currentSessionPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "CurrentSession")
    }

    static var stakeUnlockDelayPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "StakeUnlockDelay")
    }

    static var candidatesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Candidates")
    }

    static var candidateStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "CandidateStake")
    }
}
