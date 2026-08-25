import Foundation
import SubstrateSdk

extension SubtensorStakingPallet {
    static var stakingHotkeysPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "StakingHotkeys")
    }

    static var totalHotkeyAlphaPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "TotalHotkeyAlpha")
    }

    static var ownerPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "Owner")
    }

    static var subtokenEnabledPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "SubtokenEnabled")
    }

    static var tokenSymbolPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "TokenSymbol")
    }

    static var coldkeySwapAnnouncementsPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "ColdkeySwapAnnouncements")
    }

    static var taoWeightPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "TaoWeight")
    }

    static var rootStakeUnlockIntervalPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "RootStakeUnlockInterval")
    }

    static var lastColdkeyHotkeyStakeBlockPath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.name, itemName: "LastColdkeyHotkeyStakeBlock")
    }

    static var feeRatePath: StorageCodingPath {
        StorageCodingPath(moduleName: Self.swapPalletName, itemName: "FeeRate")
    }

    static var initialMinStakePath: ConstantCodingPath {
        ConstantCodingPath(moduleName: Self.name, constantName: "InitialMinStake")
    }
}
