import Foundation

struct SubtensorValidatorDirectoryItem: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let name: String?
    var take: Decimal?
    var reportedStake: BigRational?
    var status: SubtensorValidatorChainStatus?
    var isChainDetailUnavailable = false
}

extension SubtensorValidatorDirectoryItem {
    var isInactive: Bool {
        status?.hasPermit == false || status?.isActive == false
    }
}

struct SubtensorValidatorDirectory: Equatable {
    let subnet: SubtensorSubnetRef
    var items: [SubtensorValidatorDirectoryItem]
    let listStamp: SubtensorBackendStamp?
    let isPartial: Bool
}

extension SubtensorValidatorDirectory {
    func withVerification(_ verification: SubtensorValidatorListVerification) -> SubtensorValidatorDirectory {
        var directory = self

        directory.items.indices.forEach { index in
            let hotkey = directory.items[index].hotkey
            directory.items[index].take = verification.takes[hotkey]
            directory.items[index].status = verification.statuses[hotkey]
        }

        return directory
    }
}
