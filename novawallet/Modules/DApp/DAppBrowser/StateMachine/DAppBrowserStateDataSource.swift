import Foundation
import RobinHood
import BigInt

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

    func fetchChainByEthereumChainId(_ chainId: String) -> ChainModel? {
        guard let addressPrefixValue = BigUInt.fromHexString(chainId) else {
            return nil
        }

        let addressPrefix = UInt16(addressPrefixValue)

        return chainStore.values.first { model in
            model.isEthereumBased && model.addressPrefix == addressPrefix
        }
    }

    func fetchEthereumAddresses(for ethereumChainId: String?) -> [AccountAddress] {
        var addresses: [AccountAddress] = []

        let selectedAddress: String?

        if
            let ethereumChainId = ethereumChainId,
            let chain = fetchChainByEthereumChainId(ethereumChainId) {
            selectedAddress = wallet.fetch(for: chain.accountRequest())?.toAddress()
        } else {
            selectedAddress = nil
        }

        if let address = selectedAddress {
            addresses.append(address)
        }

        if let mainAddress = wallet.ethereumAddress?.toHex(includePrefix: true), mainAddress != selectedAddress {
            addresses.append(mainAddress)
        }

        let chainAddresses: [AccountAddress] = wallet.chainAccounts.compactMap { account in
            guard
                let chain = chainStore[account.chainId],
                chain.isEthereumBased,
                account.cryptoType == MultiassetCryptoType.ethereumEcdsa.rawValue,
                let address = try? account.accountId.toAddress(using: chain.chainFormat),
                address != selectedAddress else {
                return nil
            }

            return address
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
