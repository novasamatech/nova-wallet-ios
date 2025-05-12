import Foundation

protocol DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        using identities: [AccountId: AccountIdentity]
    ) throws -> ManagedMetaAccountModel

    func updateMetaAccount(
        _ metaAccount: ManagedMetaAccountModel,
        for delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId
    ) -> ManagedMetaAccountModel

    func markAsRevoked(
        _ metaAccount: ManagedMetaAccountModel,
        delegatorAccountId: AccountId
    ) -> ManagedMetaAccountModel

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DelegatedAccountProtocol,
        delegatorAccountId: AccountId
    ) -> Bool

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier?

    func canHandle(metaAccount: ManagedMetaAccountModel) -> Bool
}

struct DelegateIdentifier: Hashable {
    let delegatorAccountId: AccountId
    let delegateAccountId: AccountId
    let delegateType: DelegateType
}

enum DelegateType: Hashable {
    case proxy(Proxy.ProxyType)
    case multisig
}
