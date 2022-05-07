import Foundation

extension ParachainStaking {
    static var roundPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "Round")
    }

    static var totalPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "Total")
    }

    static var collatorCommissionPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "CollatorCommission")
    }

    static var atStakePath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "AtStake")
    }

    static var inflationConfigPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "InflationConfig")
    }

    static var parachainBondInfoPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "ParachainBondInfo")
    }

    static var stakedPath: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainStaking", itemName: "Staked")
    }
}
