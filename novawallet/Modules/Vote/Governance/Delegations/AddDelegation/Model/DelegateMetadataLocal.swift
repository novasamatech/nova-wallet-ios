import Foundation
import RobinHood
import BigInt

struct DelegateMetadataRemote {
    let address: String
    let name: String
    let image: URL?
    let shortDescription: String
    let longDescription: String?
    let isOrganization: Bool
}

struct OffChainDelegateMetadata {
    let accountId: AccountId
    let shortDescription: String
    let longDescription: String?
    let profileImageUrl: String?
    let isOrganization: Bool
    let name: String
}

struct DelegateMetadataLocal: Identifiable {
    var identifier: String {
        accountId.toHex()
    }

    let accountId: AccountId
    let name: String
    let address: String
    let shortDescription: String
    let longDescription: String?
    let profileImageUrl: String?
    let isOrganization: Bool
    let stats: DelegateStatistic?
}

struct DelegateStatistic {
    let delegations: Int
    let delegatedVotesInPlank: BigUInt
    let recentVotes: Int
}
