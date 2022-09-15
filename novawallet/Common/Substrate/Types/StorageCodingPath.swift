import Foundation

struct StorageCodingPath: Equatable {
    let moduleName: String
    let itemName: String
}

extension StorageCodingPath {
    static var account: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Account")
    }

    static var events: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Events")
    }

    static var activeEra: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ActiveEra")
    }

    static var currentEra: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "CurrentEra")
    }

    static var erasStakers: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasStakers")
    }

    static var erasPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasValidatorPrefs")
    }

    static var controller: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Bonded")
    }

    static var stakingLedger: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Ledger")
    }

    static var nominators: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Nominators")
    }

    static var validatorPrefs: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Validators")
    }

    static var totalIssuance: StorageCodingPath {
        StorageCodingPath(moduleName: "Balances", itemName: "TotalIssuance")
    }

    static var identity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "IdentityOf")
    }

    static var superIdentity: StorageCodingPath {
        StorageCodingPath(moduleName: "Identity", itemName: "SuperOf")
    }

    static var slashingSpans: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "SlashingSpans")
    }

    static var unappliedSlashes: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "UnappliedSlashes")
    }

    static var minNominatorBond: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "MinNominatorBond")
    }

    static var counterForNominators: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "CounterForNominators")
    }

    static var maxNominatorsCount: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "MaxNominatorsCount")
    }

    static var payee: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "Payee")
    }

    static var historyDepth: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "HistoryDepth")
    }

    static var totalValidatorReward: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasValidatorReward")
    }

    static var rewardPointsPerValidator: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasRewardPoints")
    }

    static var validatorExposureClipped: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasStakersClipped")
    }

    static var eraStartSessionIndex: StorageCodingPath {
        StorageCodingPath(moduleName: "Staking", itemName: "ErasStartSessionIndex")
    }

    static var currentSessionIndex: StorageCodingPath {
        StorageCodingPath(moduleName: "Session", itemName: "CurrentIndex")
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

    static var blockNumber: StorageCodingPath {
        StorageCodingPath(moduleName: "System", itemName: "Number")
    }

    static var timestampNow: StorageCodingPath {
        StorageCodingPath(moduleName: "Timestamp", itemName: "Now")
    }

    static var currentSlot: StorageCodingPath {
        StorageCodingPath(moduleName: "Babe", itemName: "CurrentSlot")
    }

    static var genesisSlot: StorageCodingPath {
        StorageCodingPath(moduleName: "Babe", itemName: "GenesisSlot")
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
