import Foundation

struct GovernanceDelegationAdditions<M> {
    let model: M
    let identities: [AccountId: AccountIdentity]
    let metadata: [AccountId: GovernanceDelegateMetadataRemote]

    func byReplacing(model: M) -> GovernanceDelegationAdditions<M> {
        .init(
            model: model,
            identities: identities,
            metadata: metadata
        )
    }

    func byReplacing(identities: [AccountId: AccountIdentity]) -> GovernanceDelegationAdditions<M> {
        .init(
            model: model,
            identities: identities,
            metadata: metadata
        )
    }

    func byReplacing(metadata: [AccountId: GovernanceDelegateMetadataRemote]) -> GovernanceDelegationAdditions<M> {
        .init(
            model: model,
            identities: identities,
            metadata: metadata
        )
    }
}
