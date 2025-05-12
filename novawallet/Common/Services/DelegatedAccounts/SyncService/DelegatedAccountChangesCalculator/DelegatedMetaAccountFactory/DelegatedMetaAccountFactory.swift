import Foundation

protocol DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        delegatorAccountId: AccountId,
        using identities: [AccountId: AccountIdentity],
        localMetaAccounts: [ManagedMetaAccountModel]
    ) throws -> ManagedMetaAccountModel

    func renew(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel

    func markAsRevoked(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DiscoveredDelegatedAccountProtocol,
        delegatorAccountId: AccountId
    ) -> Bool

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier?

    func canHandle(_ metaAccount: ManagedMetaAccountModel) -> Bool

    func canHandle(_ delegatedAccount: DiscoveredDelegatedAccountProtocol) -> Bool
}
