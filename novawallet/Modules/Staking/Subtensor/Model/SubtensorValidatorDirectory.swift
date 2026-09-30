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

struct SubtensorValidatorDetail: Equatable {
    let item: SubtensorValidatorDirectoryItem
    let identity: SubtensorValidatorIdentity?
}
