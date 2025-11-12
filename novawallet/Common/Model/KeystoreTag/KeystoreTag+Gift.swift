import Foundation

extension KeystoreTagV2 {
    static func substrateSecretKeyTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.substrateSecretKey)
    }

    static func ethereumSecretKeyTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.ethereumSecretKey)
    }

    static func entropyTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.entropy)
    }

    static func substrateDerivationTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.substrateDerivation)
    }

    static func ethereumDerivationTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.ethereumDerivation)
    }

    static func derivationTagForGift(
        accountId: AccountId,
        isEthereumBased: Bool
    ) -> String {
        if isEthereumBased {
            return ethereumDerivationTagForGift(accountId: accountId)
        } else {
            return substrateDerivationTagForGift(accountId: accountId)
        }
    }

    static func substrateSeedTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.substrateSeed)
    }

    static func ethereumSeedTagForGift(
        accountId: AccountId
    ) -> String {
        createTagForGift(accountId: accountId, suffix: Suffix.ethereumSeed)
    }
}

private extension KeystoreTagV2 {
    static func createTagForGift(
        accountId: AccountId,
        suffix: String
    ) -> String {
        accountId.toHex() + suffix
    }
}
