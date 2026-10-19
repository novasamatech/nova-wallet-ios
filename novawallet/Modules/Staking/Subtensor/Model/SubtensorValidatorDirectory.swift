import Foundation

struct SubtensorValidatorDirectoryItem: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let name: String?
    var take: Decimal?
    var reportedStake: BigRational?
    let status: SubtensorValidatorChainStatus?
    var isChainDetailUnavailable = false
}

struct SubtensorValidatorDirectory: Equatable {
    let subnet: SubtensorSubnetRef
    var items: [SubtensorValidatorDirectoryItem]
    let listStamp: SubtensorBackendStamp?
    let isPartial: Bool
}

extension SubtensorValidatorDirectory {
    func withTakes(_ takes: [AccountId: Decimal]) -> SubtensorValidatorDirectory {
        var directory = self
        directory.items.indices.forEach { directory.items[$0].take = takes[directory.items[$0].hotkey] }
        return directory
    }
}
