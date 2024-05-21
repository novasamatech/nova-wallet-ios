import SoraKeystore

final class AdvancedExportInteractor {
    weak var presenter: AdvancedExportInteractorOutputProtocol?

    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

extension AdvancedExportInteractor: AdvancedExportInteractorInputProtocol {
    func requestExportOptions(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        do {
            let substrateExportData = try substrateExportData(
                for: metaAccount,
                chain: chain
            )

            let ethereumExportData = try ethereumExportData(
                for: metaAccount,
                chain: chain
            )

            let exportData = AdvancedExportData(
                chains: [
                    .substrate(substrateExportData),
                    .ethereum(ethereumExportData)
                ]
            )

            presenter?.didReceive(exportData: exportData)
        } catch {}
    }

    func requestSeedForSubstrate(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        var accountId: AccountId?

        if let chain {
            accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())
        }

        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )

        if
            let _ = try? keystore.checkKey(for: seedTag),
            let seed = try? keystore.loadIfKeyExists(seedTag) {
            presenter?.didReceive(
                seed: seed,
                for: chain?.name ?? "Polkadot"
            )
        }
    }
}

// MARK: Private

private extension AdvancedExportInteractor {
    func ethereumExportData(
        for metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) throws -> AdvancedExportChainData {
        var accountResponse: ChainAccountResponse?
        var accountId: AccountId?
        var secretTag: String?
        var options: [SecretSource] = []

        if let chain, chain.isEthereumBased {
            accountResponse = metaAccount.fetch(for: chain.accountRequest())

            guard let accountResponse else {
                throw ChainAccountFetchingError.accountNotExists
            }

            accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())
            secretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(
                metaAccount.metaId,
                accountId: accountId
            )
        } else if let _ = metaAccount.ethereumAddress {
            secretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(
                metaAccount.metaId,
                accountId: nil
            )
        }

        let derivationTag = KeystoreTagV2.ethereumDerivationTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )
        let derivationPath = try derivationPath(for: derivationTag)

        if let secretTag, try keystore.checkKey(for: secretTag) {
            options.append(.keystore)
        }

        return .init(
            name: "Ethereum",
            availableOptions: options,
            derivationPath: derivationPath,
            cryptoType: MultiassetCryptoType.ethereumEcdsa
        )
    }

    func substrateExportData(
        for metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) throws -> AdvancedExportChainData {
        var accountResponse: ChainAccountResponse?
        var accountId: AccountId?
        var options: [SecretSource] = []

        if let chain {
            accountResponse = metaAccount.fetch(for: chain.accountRequest())
            guard let accountResponse else {
                throw ChainAccountFetchingError.accountNotExists
            }

            accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest())
        }

        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )
        let hasSeed = try keystore.checkKey(for: seedTag)

        if hasSeed || accountResponse?.cryptoType.supportsSeedFromSecretKey ?? false {
            options.append(.seed)
        }

        options.append(.keystore)

        let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )

        return .init(
            name: chain?.name ?? "Polkadot",
            availableOptions: options,
            derivationPath: try derivationPath(for: derivationTag),
            cryptoType: MultiassetCryptoType(rawValue: metaAccount.substrateCryptoType!)!
        )
    }

    func derivationPath(for tag: String) throws -> String? {
        guard let derivationPathData = try keystore.loadIfKeyExists(tag) else {
            return .none
        }

        return String(data: derivationPathData, encoding: .utf8)
    }
}
