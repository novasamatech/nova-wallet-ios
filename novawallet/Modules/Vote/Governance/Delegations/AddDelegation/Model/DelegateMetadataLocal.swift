import Foundation
import RobinHood
import BigInt

struct GovernanceDelegateLocal {
    let stats: GovernanceDelegateStats
    let metadata: GovernanceDelegateMetadataRemote?
}

extension GovernanceDelegateLocal: Identifiable {
    var identifier: String {
        stats.address
    }
}

struct GovernanceDelegateMetadataRemote: Decodable {
    let address: AccountAddress
    let name: String
    let image: URL
    let shortDescription: String
    let longDescription: String?
    let isOrganization: Bool
}

struct GovernanceDelegateStats {
    let address: AccountAddress
    let delegationsCount: UInt64
    let delegatedVotes: BigUInt
    let recentVotes: UInt64
}
