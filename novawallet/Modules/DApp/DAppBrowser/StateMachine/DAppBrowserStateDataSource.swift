import Foundation
import Operation_iOS
import BigInt

final class DAppBrowserStateDataSource {
    private(set) var chainStore: [String: ChainModel] = [:]
    private(set) var metadataStore: [String: PolkadotExtensionMetadata] = [:]
    let signBytesChainResolver = DAppSignBytesChainResolver()

    let wallet: MetaAccountModel
    let chainRegistry: ChainRegistryProtocol
    let dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>
    let operationQueue: OperationQueue
    private(set) var tab: DAppBrowserTab?

    init(
        wallet: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        dAppSettingsRepository: AnyDataProviderRepository<DAppSettings>,
        operationQueue: OperationQueue,
        tab: DAppBrowserTab?
    ) {
        self.wallet = wallet
        self.chainRegistry = chainRegistry
        self.dAppSettingsRepository = dAppSettingsRepository
        self.operationQueue = operationQueue
        self.tab = tab
    }

    func set(metadata: PolkadotExtensionMetadata, for key: String) {
        metadataStore[key] = metadata
    }

    func set(chain: ChainModel?, for key: String) {
        chainStore[key] = chain
    }

    func replace(tab: DAppBrowserTab?) {
        self.tab = tab
    }

    func fetchAccountList() throws -> [PolkadotExtensionAccount] {
        var accounts: [PolkadotExtensionAccount] = []

        if let substrateAccountId = wallet.substrateAccountId, let cryptoType = wallet.substrateCryptoType {
            let substrateAccount = try createExtensionAccount(
                for: substrateAccountId,
                genesisHash: nil,
                name: wallet.name,
                chainFormat: .defaultSubstrateFormat,
                rawCryptoType: cryptoType
            )

            accounts.append(substrateAccount)
        }

        if let ethereumAddress = wallet.ethereumAddress {
            let ethereumAccount = try createExtensionAccount(
                for: ethereumAddress,
                genesisHash: nil,
                name: wallet.name,
                chainFormat: .ethereum,
                rawCryptoType: MultiassetCryptoType.ethereumEcdsa.rawValue
            )

            accounts.append(ethereumAccount)
        }

        let chainAccounts: [PolkadotExtensionAccount] = try wallet.chainAccounts.compactMap { chainAccount in
            guard let chain = chainStore[chainAccount.chainId] else {
                return nil
            }

            let name = wallet.name + " (\(chain.name))"

            return try createExtensionAccount(
                for: chainAccount.accountId,
                genesisHash: chain.genesisHash,
                name: name,
                chainFormat: chain.chainFormat,
                rawCryptoType: chainAccount.cryptoType
            )
        }

        accounts.append(contentsOf: chainAccounts)

        return accounts
    }

    func fetchChainByEthereumChainId(_ chainId: String) -> ChainModel? {
        guard let addressPrefixValue = BigUInt.fromHexString(chainId) else {
            return nil
        }

        return chainStore.values.first { model in
            model.isEthereumBased && BigUInt(model.addressPrefix) == addressPrefixValue
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

    func resolveSignBytesChain(for address: AccountAddress) throws -> ChainModel {
        try signBytesChainResolver.resolveChainForBytesSigning(
            for: address,
            wallet: wallet,
            chains: Array(chainStore.values)
        )
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
