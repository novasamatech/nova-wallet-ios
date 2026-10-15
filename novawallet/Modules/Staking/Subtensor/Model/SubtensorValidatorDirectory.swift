import Foundation

struct SubtensorValidatorDirectoryItem: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let name: String?
    var take: Decimal?
    let reportedStake: BigRational?
    let status: SubtensorValidatorChainStatus?
}

extension SubtensorValidatorDirectoryItem {
    func withoutReportedStake() -> SubtensorValidatorDirectoryItem {
        SubtensorValidatorDirectoryItem(
            hotkey: hotkey,
            netuid: netuid,
            name: name,
            take: take,
            reportedStake: nil,
            status: status
        )
    }
}

struct SubtensorValidatorDirectory: Equatable {
    let subnet: SubtensorSubnetRef
    let items: [SubtensorValidatorDirectoryItem]
    let listStamp: SubtensorBackendStamp?
    let isPartial: Bool
}

extension SubtensorValidatorDirectory {
    func withTakes(_ takes: [AccountId: Decimal]) -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: subnet,
            items: items.map { item in
                var item = item
                item.take = takes[item.hotkey]
                return item
            },
            listStamp: listStamp,
            isPartial: isPartial
        )
    }
}
