import Foundation

struct SubtensorValidatorDirectoryItem: Equatable {
    let hotkey: AccountId
    let netuid: UInt16
    let name: String?
    let take: Decimal?
    let reportedStake: BigRational?
    let status: SubtensorValidatorChainStatus?
}

struct SubtensorValidatorDirectory: Equatable {
    let subnet: SubtensorSubnetRef
    let items: [SubtensorValidatorDirectoryItem]
    let listStamp: SubtensorBackendStamp?
    let isPartial: Bool
    let isEnrichmentTruncated: Bool
    let chainBlock: BlockNumber
}

extension SubtensorValidatorDirectory {
    func markingStale() -> SubtensorValidatorDirectory {
        SubtensorValidatorDirectory(
            subnet: subnet,
            items: items,
            listStamp: listStamp.map { SubtensorBackendStamp(asOf: $0.asOf, freshness: .stale) },
            isPartial: isPartial,
            isEnrichmentTruncated: isEnrichmentTruncated,
            chainBlock: chainBlock
        )
    }
}

struct SubtensorValidatorDetail: Equatable {
    let item: SubtensorValidatorDirectoryItem
    let identity: SubtensorValidatorIdentity?
}
