import Foundation

struct GovernanceDelegateFlowDisplayInfo {
    let selectedTracks: [GovernanceTrackInfoLocal]
    let delegateMetadata: GovernanceDelegateMetadataRemote?
    let delegateIdentity: AccountIdentity?
}
