struct AccountImportVisibility: OptionSet {
    let rawValue: Int

    static let sourceType = AccountImportVisibility(rawValue: 1 << 0)
    static let walletName = AccountImportVisibility(rawValue: 1 << 1)
    static let restoreJSON = AccountImportVisibility(rawValue: 1 << 2)
    static let password = AccountImportVisibility(rawValue: 1 << 3)
    static let substrateCryptoType = AccountImportVisibility(rawValue: 1 << 4)
    static let substrateDerivationPath = AccountImportVisibility(rawValue: 1 << 5)
    static let ethereumCryptoType = AccountImportVisibility(rawValue: 1 << 6)
    static let ethereumDerivationPath = AccountImportVisibility(rawValue: 1 << 7)
    static let mnemonicText = AccountImportVisibility(rawValue: 1 << 8)
    static let seedText = AccountImportVisibility(rawValue: 1 << 9)
    static let networkType = AccountImportVisibility(rawValue: 1 << 10)

    static let walletMnemonic: AccountImportVisibility = [
        .sourceType,
        .walletName,
        .mnemonicText,
        .substrateCryptoType,
        .substrateDerivationPath,
        .ethereumCryptoType,
        .ethereumDerivationPath
    ]

    static let substrateChainMnemonic: AccountImportVisibility = [
        .sourceType,
        .mnemonicText,
        .substrateCryptoType,
        .substrateDerivationPath
    ]

    static let ethereumChainMnemonic: AccountImportVisibility = [
        .sourceType,
        .mnemonicText,
        .ethereumCryptoType,
        .ethereumDerivationPath
    ]

    static let walletSeed: AccountImportVisibility = [
        .sourceType,
        .walletName,
        .seedText,
        .substrateCryptoType,
        .substrateDerivationPath
    ]

    static let substrateChainSeed: AccountImportVisibility = [
        .sourceType,
        .seedText,
        .substrateCryptoType,
        .substrateDerivationPath
    ]

    static let ethereumChainSeed: AccountImportVisibility = [
        .sourceType,
        .seedText,
        .ethereumCryptoType,
        .ethereumDerivationPath
    ]

    static let walletJSON: AccountImportVisibility = [
        .sourceType,
        .restoreJSON,
        .walletName,
        .password,
        .substrateCryptoType
    ]

    static let substrateChainJSON: AccountImportVisibility = [
        .sourceType,
        .restoreJSON,
        .password,
        .substrateCryptoType
    ]

    static let ethereumChainJSON: AccountImportVisibility = [
        .sourceType,
        .restoreJSON,
        .password,
        .ethereumCryptoType
    ]
}
