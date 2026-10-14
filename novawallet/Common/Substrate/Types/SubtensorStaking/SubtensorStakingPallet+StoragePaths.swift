import Foundation
import SubstrateSdk

extension SubtensorStakingPallet {
    static var stakingHotkeysPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "StakingHotkeys")
    }

    static var totalHotkeyAlphaPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "TotalHotkeyAlpha")
    }

    static var ownerPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Owner")
    }

    static var delegatesTakePath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Delegates")
    }

    static var subnetEmissionEnabledPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "SubnetEmissionEnabled")
    }

    static var subtokenEnabledPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "SubtokenEnabled")
    }

    static var networksAddedPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "NetworksAdded")
    }

    static var coldkeySwapAnnouncementsPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "ColdkeySwapAnnouncements")
    }

    static var rootStakeUnlockIntervalPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "RootStakeUnlockInterval")
    }

    static var lastColdkeyHotkeyStakeBlockPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "LastColdkeyHotkeyStakeBlock")
    }

    static var feeRatePath: StorageCodingPath {
        StorageCodingPath(moduleName: swapPalletName, itemName: "FeeRate")
    }

    static var nominatorMinRequiredStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "NominatorMinRequiredStake")
    }

    static var safeModeEnteredUntilPath: StorageCodingPath {
        StorageCodingPath(moduleName: safeModePalletName, itemName: "EnteredUntil")
    }

    static var uidsPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Uids")
    }

    static var validatorPermitPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "ValidatorPermit")
    }

    static var lastUpdatePath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "LastUpdate")
    }

    static var tempoPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "Tempo")
    }

    static var activityCutoffFactorMilliPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "ActivityCutoffFactorMilli")
    }

    static var initialMinStakePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "InitialMinStake")
    }
}
