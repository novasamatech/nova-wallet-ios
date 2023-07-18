import Foundation

extension NominationPools {
    static var poolMembersPath: StorageCodingPath {
        .init(moduleName: "NominationPools", itemName: "PoolMembers")
    }

    static var palletId: ConstantCodingPath {
        .init(moduleName: "NominationPools", constantName: "PalletId")
    }
}
