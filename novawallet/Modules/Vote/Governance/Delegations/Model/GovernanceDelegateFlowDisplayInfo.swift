import Foundation

struct GovernanceDelegateFlowDisplayInfo<M> {
    let additions: M
    let delegateMetadata: GovernanceDelegateMetadataRemote?
    let delegateIdentity: AccountIdentity?
}
