import Foundation
import RobinHood

final class DAppBrowserStateDataSource {
    private(set) var chainStore: [String: ChainModel] = [:]
    private(set) var metadataStore: [String: PolkadotExtensionMetadata] = [:]
    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>
    let operationQueue: OperationQueue
    let dApp: DApp?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        operationQueue: OperationQueue,
        dApp: DApp?
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.dAppSettingsRepository = dAppSettingsRepository
        self.operationQueue = operationQueue
        self.dApp = dApp
    }

    func set(metadata: PolkadotExtensionMetadata, for key: String) {
        metadataStore[key] = metadata
    }

    func set(chain: ChainModel?, for key: String) {
        chainStore[key] = chain
    }

    func fetchAccountList() throws -> [PolkadotExtensionAccount] {
        let substrateAccount = try createExtensionAccount(
            for: wallet.substrateAccountId,
            genesisHash: nil,
            name: wallet.name,
            chainFormat: .substrate(42),
            rawCryptoType: wallet.substrateCryptoType
        )

        let chainAccounts: [PolkadotExtensionAccount] = try wallet.chainAccounts.compactMap { chainAccount in
            guard let chain = chainStore[chainAccount.chainId], !chain.isEthereumBased else {
                return nil
            }

            let genesisHash = try Data(hexString: chain.chainId)
            let name = wallet.name + " (\(chain.name))"

            return try createExtensionAccount(
                for: chainAccount.accountId,
                genesisHash: genesisHash,
                name: name,
                chainFormat: chain.chainFormat,
                rawCryptoType: chainAccount.cryptoType
            )
        }

        return [substrateAccount] + chainAccounts
    }

    func fetchEthereumAddresses() -> [AccountAddress] {
        var addresses: [AccountAddress] = []

        if let mainAddress = wallet.ethereumAddress {
            addresses.append(mainAddress.toHex(includePrefix: true))
        }

        let chainAddresses: [AccountAddress] = wallet.chainAccounts.compactMap { account in
            guard
                let chain = chainStore[account.chainId],
                chain.isEthereumBased,
                account.cryptoType == MultiassetCryptoType.ethereumEcdsa.rawValue else {
                return nil
            }

            return try? account.accountId.toAddress(using: chain.chainFormat)
        }

        addresses.append(contentsOf: chainAddresses)

        return addresses
    }

    private func createExtensionAccount(
        for accountId: AccountId,
        genesisHash: Data?,
        name: String,
        chainFormat: ChainFormat,
        rawCryptoType: UInt8
    ) throws -> PolkadotExtensionAccount {
        let address = try accountId.toAddress(using: chainFormat)

        let keypairType: PolkadotExtensionKeypairType?
        if let substrateCryptoType = MultiassetCryptoType(rawValue: rawCryptoType) {
            keypairType = PolkadotExtensionKeypairType(cryptoType: substrateCryptoType)
        } else {
            keypairType = nil
        }

        return PolkadotExtensionAccount(
            address: address,
            genesisHash: genesisHash?.toHex(includePrefix: true),
            name: name,
            type: keypairType
        )
    }
}
