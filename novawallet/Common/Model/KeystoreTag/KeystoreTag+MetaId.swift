import Foundation

extension KeystoreTagV2 {
    static func substrateSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.substrateSecretKey)
    }
    
    static func ethereumSecretKeyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.ethereumSecretKey)
    }
    
    static func entropyTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.entropy)
    }
    
    static func substrateDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.substrateDerivation)
    }
    
    static func ethereumDerivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.ethereumDerivation)
    }
    
    static func derivationTagForMetaId(
        _ metaId: String,
        accountId: AccountId,
        isEthereumBased: Bool
    ) -> String {
        if isEthereumBased {
            return ethereumDerivationTagForMetaId(metaId, accountId: accountId)
        } else {
            return substrateDerivationTagForMetaId(metaId, accountId: accountId)
        }
    }
    
    static func substrateSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.substrateSeed)
    }
    
    static func ethereumSeedTagForMetaId(
        _ metaId: String,
        accountId: AccountId? = nil
    ) -> String {
        createTagForMetaId(metaId, accountId: accountId, suffix: Suffix.ethereumSeed)
    }
}

fileprivate extension KeystoreTagV2 {
    static func createTagForMetaId(
        _ metaId: String,
        accountId: AccountId?,
        suffix: String
    ) -> String {
        accountId.map { metaId + $0.toHex() + suffix } ?? metaId + suffix
    }
}
