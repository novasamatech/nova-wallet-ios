import Foundation

extension NominationPools {
    static var poolMembersPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "PoolMembers")
    }

    static var palletIdPath: ConstantCodingPath {
        .init(moduleName: "NominationPools", constantName: "PalletId")
    }

    static var bondedPoolPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "BondedPools")
    }

    static var lastPoolIdPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "LastPoolId")
    }

    static var minJoinBondPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "MinJoinBond")
    }

    static var metadataPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "Metadata")
    }

    static var rewardPoolsPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "RewardPools")
    }

    static var subPoolsPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "SubPoolsStorage")
    }

    static var maxPoolMembers: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "MaxPoolMembers")
    }

    static var counterForPoolMembers: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "CounterForPoolMembers")
    }

    static var maxMembersPerPool: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "MaxPoolMembersPerPool")
    }
}
