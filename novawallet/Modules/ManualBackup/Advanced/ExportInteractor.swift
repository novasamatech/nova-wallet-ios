import Keystore_iOS

final class ExportInteractor {
    weak var presenter: ExportInteractorOutputProtocol?

    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

extension ExportInteractor: ExportInteractorInputProtocol {
    func requestExportOptions(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        var exportSubstrate: Bool {
            if let chain {
                !chain.isEthereumBased
            } else {
                metaAccount.substrateAccountId != .none
            }
        }

        var exportEthereum: Bool {
            if let chain {
                chain.isEthereumBased
            } else {
                metaAccount.ethereumAddress != .none
            }
        }

        var chains: [ExportData.ChainType] = []

        do {
            if exportSubstrate {
                let chainExportData = try substrateExportData(
                    for: metaAccount,
                    chain: chain
                )
                chains.append(.substrate(chainExportData))
            }
            if exportEthereum {
                let chainExportData = try ethereumExportData(
                    for: metaAccount,
                    chain: chain
                )
                chains.append(.ethereum(chainExportData))
            }
            let exportData = ExportData(chains: chains)

            presenter?.didReceive(exportData: exportData)
        } catch {
            presenter?.didReceive(error)
        }
    }

    func requestSeedForSubstrate(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        guard let secret = fetchSecret(
            with: metaAccount,
            chain: chain,
            chainType: .substrate
        ) else {
            return
        }

        presenter?.didReceive(
            seed: secret,
            for: chain?.name ?? ChainType.substrate.rawValue
        )
    }

    func requestKeyForEthereum(
        metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) {
        guard let secret = fetchSecret(
            with: metaAccount,
            chain: chain,
            chainType: .ethereum
        ) else {
            return
        }

        presenter?.didReceive(
            seed: secret,
            for: chain?.name ?? ChainType.ethereum.rawValue
        )
    }
}

// MARK: Private

private extension ExportInteractor {
    func fetchSecret(
        with metaAccount: MetaAccountModel,
        chain: ChainModel?,
        chainType: ChainType
    ) -> Data? {
        let accountId = try? accountId(
            for: chain,
            metaAccount: metaAccount
        )

        let keystoreTag: String = switch chainType {
        case .ethereum:
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(
                metaAccount.metaId,
                accountId: accountId
            )
        case .substrate:
            KeystoreTagV2.substrateSeedTagForMetaId(
                metaAccount.metaId,
                accountId: accountId
            )
        }

        return try? keystore.loadIfKeyExists(keystoreTag)
    }

    func ethereumExportData(
        for metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) throws -> ExportChainData {
        var options: [SecretSource] = []

        let accountId = try accountId(
            for: chain,
            metaAccount: metaAccount
        )

        let secretTag = KeystoreTagV2.ethereumSecretKeyTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )

        let derivationTag = KeystoreTagV2.ethereumDerivationTagForMetaId(
            metaAccount.metaId,
            accountId: accountId
        )
        let derivationPath = try derivationPath(for: derivationTag)

        if try keystore.checkKey(for: secretTag) {
            options.append(.keystore)
        }

        return .init(
            name: ChainType.ethereum.rawValue,
            availableOptions: options,
            derivationPath: derivationPath,
            cryptoType: MultiassetCryptoType.ethereumEcdsa
        )
    }

    func substrateExportData(
        for metaAccount: MetaAccountModel,
        chain: ChainModel?
    ) throws -> ExportChainData {
        let accountResponse = try accountResponse(
            for: chain,
            metaAccount: metaAccount
        )

        var options: [SecretSource] = []

        let seedTag = KeystoreTagV2.substrateSeedTagForMetaId(
            metaAccount.metaId,
            accountId: accountResponse?.accountId
        )
        let hasSeed = try keystore.checkKey(for: seedTag)

        if hasSeed || accountResponse?.cryptoType.supportsSeedFromSecretKey ?? false {
            options.append(.seed)
        }

        options.append(.keystore)

        let derivationTag = KeystoreTagV2.substrateDerivationTagForMetaId(
            metaAccount.metaId,
            accountId: accountResponse?.accountId
        )

        return .init(
            name: chain?.name ?? ChainType.substrate.rawValue,
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

    func accountId(
        for chain: ChainModel?,
        metaAccount: MetaAccountModel
    ) throws -> AccountId? {
        if let chain {
            guard let accountId = metaAccount.fetchChainAccountId(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            return accountId
        }

        return .none
    }

    func accountResponse(
        for chain: ChainModel?,
        metaAccount: MetaAccountModel
    ) throws -> ChainAccountResponse? {
        if let chain {
            guard let accountResponse = metaAccount.fetch(for: chain.accountRequest()) else {
                throw ChainAccountFetchingError.accountNotExists
            }

            return accountResponse
        }

        return .none
    }
}

private extension ExportInteractor {
    enum ChainType: String {
        case substrate = "Polkadot"
        case ethereum = "Ethereum"
    }
}
