import Foundation

struct GovernanceDelegateLocal {
    let stats: GovernanceDelegateStats
    let metadata: GovernanceDelegateMetadataRemote?
    let identity: AccountIdentity?

    var displayName: String? {
        identity?.displayName ?? metadata?.name
    }
}
