import Foundation

protocol DelegatedMetaAccountFactoryProtocol {
    func createMetaAccount(
        for delegatedAccount: DiscoveredDelegatedAccountProtocol,
        using identities: [AccountId: AccountIdentity],
        metaAccounts: [ManagedMetaAccountModel]
    ) throws -> ManagedMetaAccountModel?

    func renew(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel

    func markAsRevoked(_ metaAccount: ManagedMetaAccountModel) -> ManagedMetaAccountModel

    func matchesDelegatedAccount(
        _ metaAccount: ManagedMetaAccountModel,
        delegatedAccount: DiscoveredDelegatedAccountProtocol
    ) -> Bool

    func extractDelegateIdentifier(from metaAccount: ManagedMetaAccountModel) -> DelegateIdentifier?

    func canHandle(_ metaAccount: ManagedMetaAccountModel) -> Bool

    func canHandle(_ delegatedAccount: DiscoveredDelegatedAccountProtocol) -> Bool
}
