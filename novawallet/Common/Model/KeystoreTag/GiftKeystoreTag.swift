import Foundation

enum GiftKeystoreTag {
    enum Suffix {
        static let substrateSecretKey = "substrateSecretKey"
        static let ethereumSecretKey = "ethereumSecretKey"
        static let substrateDerivation = "substrateDeriv"
        static let ethereumDerivation = "ethereumDeriv"
        static let substrateSeed = "substrateSeed"
        static let ethereumSeed = "ethereumSeed"
    }

    static let prefix: String = "gift"
}

extension GiftKeystoreTag {
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

private extension GiftKeystoreTag {
    static func createTagForGift(
        accountId: AccountId,
        suffix: String
    ) -> String {
        [
            prefix,
            accountId.toHex(),
            suffix
        ].joined(with: .dash)
    }
}
