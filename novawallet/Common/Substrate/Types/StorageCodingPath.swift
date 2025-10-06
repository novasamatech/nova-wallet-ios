import Foundation

struct StorageCodingPath: Equatable {
    let moduleName: String
    let itemName: String
}

extension StorageCodingPath {
    static var totalIssuance: StorageCodingPath {
        StorageCodingPath(moduleName: "Balances", itemName: "TotalIssuance")
    }

    static var inactiveIssuance: StorageCodingPath {
        StorageCodingPath(moduleName: "Balances", itemName: "InactiveIssuance")
    }

    static var identity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "IdentityOf")
    }

    static var superIdentity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "SuperOf")
    }

    static var electionPhase: StorageCodingPath {
        StorageCodingPath(moduleName: "ElectionProviderMultiPhase", itemName: "CurrentPhase")
    }

    static var parachains: StorageCodingPath {
        StorageCodingPath(moduleName: "Paras", itemName: "Parachains")
    }

    static var parachainSlotLeases: StorageCodingPath {
        StorageCodingPath(moduleName: "Slots", itemName: "Leases")
    }

    static var crowdloanFunds: StorageCodingPath {
        StorageCodingPath(moduleName: "Crowdloan", itemName: "Funds")
    }

    static var timestampNow: StorageCodingPath {
        StorageCodingPath(moduleName: "Timestamp", itemName: "Now")
    }

    static var balanceLocks: StorageCodingPath {
        StorageCodingPath(moduleName: "Balances", itemName: "Locks")
    }

    static func assetsAccount(from moduleName: String?) -> StorageCodingPath {
        StorageCodingPath(moduleName: moduleName ?? "Assets", itemName: "Account")
    }

    static func assetsDetails(from moduleName: String?) -> StorageCodingPath {
        StorageCodingPath(moduleName: moduleName ?? "Assets", itemName: "Asset")
    }

    static var ormlTokenAccount: StorageCodingPath {
        StorageCodingPath(moduleName: "Tokens", itemName: "Accounts")
    }

    static var ormlTokenLocks: StorageCodingPath {
        StorageCodingPath(moduleName: "Tokens", itemName: "Locks")
    }

    static var ormlTotalIssuance: StorageCodingPath {
        StorageCodingPath(moduleName: "Tokens", itemName: "TotalIssuance")
    }

    static var uniquesAccount: StorageCodingPath {
        StorageCodingPath(moduleName: "Uniques", itemName: "Account")
    }

    static var uniquesClassMetadata: StorageCodingPath {
        StorageCodingPath(moduleName: "Uniques", itemName: "ClassMetadataOf")
    }

    static var uniquesInstanceMetadata: StorageCodingPath {
        StorageCodingPath(moduleName: "Uniques", itemName: "InstanceMetadataOf")
    }

    static var uniquesClassDetails: StorageCodingPath {
        StorageCodingPath(moduleName: "Uniques", itemName: "Class")
    }

    static var parachainId: StorageCodingPath {
        StorageCodingPath(moduleName: "ParachainInfo", itemName: "ParachainId")
    }
}
