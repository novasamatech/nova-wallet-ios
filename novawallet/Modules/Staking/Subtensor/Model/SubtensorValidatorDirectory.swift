import Foundation

struct SubtensorValidatorDirectoryItem: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let name: String?
    let take: Decimal?
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
    let isEnrichmentTruncated: Bool
}
