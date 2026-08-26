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

    static var subtokenEnabledPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "SubtokenEnabled")
    }

    static var networksAddedPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "NetworksAdded")
    }

    static var tokenSymbolPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "TokenSymbol")
    }

    static var coldkeySwapAnnouncementsPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "ColdkeySwapAnnouncements")
    }

    static var taoWeightPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "TaoWeight")
    }

    /// chain-wide StorageValue, not a per-subnet map (subtensor: `pallets/subtensor/src/lib.rs:2015`)
    static var subnetOwnerCutPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "SubnetOwnerCut")
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

    static var rootClaimableThresholdPath: StorageCodingPath {
        StorageCodingPath(moduleName: name, itemName: "RootClaimableThreshold")
    }

    static var safeModeEnteredUntilPath: StorageCodingPath {
        StorageCodingPath(moduleName: safeModePalletName, itemName: "EnteredUntil")
    }

    static var initialMinStakePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "InitialMinStake")
    }

    static var initialDefaultDelegateTakePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: name, constantName: "InitialDefaultDelegateTake")
    }
}
