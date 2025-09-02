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

    static var invulnerablesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Invulnerables")
    }

    static var releaseQueuesPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "ReleaseQueues")
    }

    static var autoCompoundPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "AutoCompound")
    }

    static var maxStakedCandidatesPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MaxStakedCandidates")
    }

    static var maxStakersPerCandidatePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "MaxStakers")
    }

    static var collatorRewardPercentagePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "CollatorRewardPercentage")
    }

    static var extraRewardPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "ExtraReward")
    }
}
