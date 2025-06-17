import Foundation

struct ChainAccountRequest {
    struct Properties {
        let addressPrefix: ChainModel.AddressPrefix
        let isEthereumBased: Bool
        let supportsGenericLedger: Bool
        let hasSubstrateRuntime: Bool
    }

    let chainId: ChainModel.Id
    let parentId: ChainModel.Id?
    let properties: Properties

    var addressPrefix: ChainModel.AddressPrefix {
        properties.addressPrefix
    }

    var isEthereumBased: Bool {
        properties.isEthereumBased
    }

    var supportsGenericLedger: Bool {
        properties.supportsGenericLedger
    }

    var hasSubstrateRuntime: Bool {
        properties.hasSubstrateRuntime
    }
}

struct ChainAccountResponse {
    let metaId: String
    let chainId: ChainModel.Id
    let accountId: AccountId
    let publicKey: Data
    let name: String
    let cryptoType: MultiassetCryptoType
    let addressPrefix: ChainModel.AddressPrefix
    let isEthereumBased: Bool
    let isChainAccount: Bool
    let type: MetaAccountModelType
}

struct MetaEthereumAccountResponse {
    let metaId: String
    let address: AccountId
    let publicKey: Data
    let name: String
    let isChainAccount: Bool
    let type: MetaAccountModelType
}

struct MetaChainAccountResponse {
    let metaId: String
    let substrateAccountId: AccountId?
    let ethereumAccountId: AccountId?
    let walletIdenticonData: Data?
    let chainAccount: ChainAccountResponse
}

enum ChainAccountFetchingError: Error {
    case accountNotExists
}

extension MetaChainAccountResponse {
    func toWalletDisplayAddress() throws -> WalletDisplayAddress {
        let displayAddress = try chainAccount.toDisplayAddress()

        return WalletDisplayAddress(
            address: displayAddress.address,
            walletName: displayAddress.username,
            walletIconData: substrateAccountId
        )
    }
}

extension ChainAccountResponse {
    var chainFormat: ChainFormat {
        isEthereumBased
            ? .ethereum
            : .substrate(addressPrefix.toSubstrateFormat())
    }

    func toDisplayAddress() throws -> DisplayAddress {
        let chainFormat: ChainFormat = isEthereumBased
            ? .ethereum
            : .substrate(addressPrefix.toSubstrateFormat())
        let address = try accountId.toAddress(using: chainFormat)

        return DisplayAddress(address: address, username: name)
    }

    func toAddress() -> AccountAddress? {
        let chainFormat: ChainFormat = isEthereumBased
            ? .ethereum
            : .substrate(addressPrefix.toSubstrateFormat())
        return try? accountId.toAddress(using: chainFormat)
    }

    // TODO: Remove when fully migrate to Ethereum checksumed addresses
    func toChecksumedAddress() -> AccountAddress? {
        let optAddress = toAddress()

        if isEthereumBased {
            return optAddress?.toEthereumAddressWithChecksum()
        } else {
            return optAddress
        }
    }
}

extension ChainModel {
    func accountRequest() -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            parentId: parentId,
            properties: ChainAccountRequest.Properties(
                addressPrefix: addressPrefix,
                isEthereumBased: isEthereumBased,
                supportsGenericLedger: supportsGenericLedgerApp,
                hasSubstrateRuntime: hasSubstrateRuntime
            )
        )
    }

    var accountIdSize: Int {
        Self.getAccountIdSize(for: chainFormat)
    }

    static func getAccountIdSize(for chainFormat: ChainFormat) -> Int {
        switch chainFormat {
        case .substrate:
            return 32
        case .ethereum:
            return 20
        }
    }

    func emptyAccountId() throws -> AccountId {
        guard let accountId = Data.random(of: accountIdSize) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        return accountId
    }

    static func getEvmNullAccountId() -> AccountId {
        AccountId.zeroAccountId(of: getAccountIdSize(for: .ethereum))
    }
}
