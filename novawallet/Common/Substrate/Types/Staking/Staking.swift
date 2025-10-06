import Foundation
import BigInt
import SubstrateSdk

enum Staking {
    static let module = "Staking"

    static var historyDepthStoragePath: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "HistoryDepth")
    }

    static var erasStakers: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasStakers")
    }

    static var eraStakersOverview: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasStakersOverview")
    }

    static var eraStakersPaged: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasStakersPaged")
    }

    static var eraValidatorPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasValidatorPrefs")
    }

    static var claimedRewards: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ClaimedRewards")
    }

    static var slashingSpans: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "SlashingSpans")
    }

    static var unappliedSlashes: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "UnappliedSlashes")
    }

    static var minNominatorBond: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "MinNominatorBond")
    }

    static var counterForNominators: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "CounterForNominators")
    }

    static var maxNominatorsCount: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "MaxNominatorsCount")
    }

    static var payee: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "Payee")
    }

    static var historyDepth: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "HistoryDepth")
    }

    static var totalValidatorReward: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasValidatorReward")
    }

    static var rewardPointsPerValidator: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ErasRewardPoints")
    }

    static var bondedEras: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "BondedEras")
    }

    static var activeEra: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "ActiveEra")
    }

    static var currentEra: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "CurrentEra")
    }

    static var controller: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "Bonded")
    }

    static var stakingLedger: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "Ledger")
    }

    static var nominators: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "Nominators")
    }

    static var validatorPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: module, itemName: "Validators")
    }

    static var historyDepthCostantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "HistoryDepth")
    }

    static var maxUnlockingChunksConstantPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "MaxUnlockingChunks")
    }

    static var slashDeferDurationPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "SlashDeferDuration")
    }

    static var maxNominatorRewardedPerValidatorPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "MaxNominatorRewardedPerValidator")
    }

    static var lockUpPeriodPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "BondingDuration")
    }

    static var eraLengthPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "SessionsPerEra")
    }

    static var maxNominationsPath: ConstantCodingPath {
        ConstantCodingPath(moduleName: module, constantName: "MaxNominations")
    }
}
