import Foundation

struct ChainAccountRequest {
    let chainId: ChainModel.Id
    let addressPrefix: UInt16
    let isEthereumBased: Bool
}

struct ChainAccountResponse {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let publicKey: Data
    let name: String
    let cryptoType: MultiassetCryptoType
    let addressPrefix: UInt16
    let isEthereumBased: Bool
    let isChainAccount: Bool
}

struct MetaEthereumAccountResponse {
    let metaId: String
    let address: AccountId
    let publicKey: Data
    let name: String
    let isChainAccount: Bool
}

struct MetaChainAccountResponse {
    let metaId: String
    let substrateAccountId: AccountId
    let ethereumAccountId: AccountId?
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
        isEthereumBased ? .ethereum : .substrate(addressPrefix)
    }

    func toDisplayAddress() throws -> DisplayAddress {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        let address = try accountId.toAddress(using: chainFormat)

        return DisplayAddress(address: address, username: name)
    }

    func toAddress() -> AccountAddress? {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
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

extension MetaAccountModel {
    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
            guard let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true
            )
        }

        if request.isEthereumBased {
            guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false
            )
        }

        guard let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false
        )
    }

    // Note that this query might return an account in another chain if it can't be found for provided chain
    func fetchByAccountId(_ accountId: AccountId, request: ChainAccountRequest) -> ChainAccountResponse? {
        if
            let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId && $0.accountId == accountId }),
            let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) {
            return ChainAccountResponse(
                chainId: chainAccount.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true
            )
        }

        if
            request.isEthereumBased,
            let publicKey = ethereumPublicKey,
            let ethereumAccountId = ethereumAddress,
            ethereumAccountId == accountId {
            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: ethereumAccountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false
            )
        }

        if
            !request.isEthereumBased,
            substrateAccountId == accountId,
            let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) {
            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: substrateAccountId,
                publicKey: substratePublicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: false,
                isChainAccount: false
            )
        }

        // if we can't match by chain still try to find account connected to another chain
        if
            let chainAccount = chainAccounts.first(where: { $0.accountId == accountId }),
            let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) {
            return ChainAccountResponse(
                chainId: chainAccount.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true
            )
        }

        return nil
    }

    func fetchEthereum(for address: AccountId) -> MetaEthereumAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.accountId == address }) {
            return MetaEthereumAccountResponse(
                metaId: metaId,
                address: address,
                publicKey: chainAccount.publicKey,
                name: name,
                isChainAccount: true
            )
        }

        guard
            let publicKey = ethereumPublicKey,
            let ethereumAddress = ethereumAddress,
            ethereumAddress == address else {
            return nil
        }

        return MetaEthereumAccountResponse(
            metaId: metaId,
            address: address,
            publicKey: publicKey,
            name: name,
            isChainAccount: false
        )
    }

    func fetchMetaChainAccount(for request: ChainAccountRequest) -> MetaChainAccountResponse? {
        fetch(for: request).map {
            MetaChainAccountResponse(
                metaId: metaId,
                substrateAccountId: substrateAccountId,
                ethereumAccountId: ethereumAddress,
                chainAccount: $0
            )
        }
    }

    func fetchChainAccountId(for request: ChainAccountRequest) -> AccountId? {
        chainAccounts.first(where: { $0.chainId == request.chainId })?.accountId
    }

    func contains(accountId: AccountId) -> Bool {
        substrateAccountId == accountId ||
            ethereumAddress == accountId ||
            chainAccounts.contains(where: { $0.accountId == accountId })
    }
}

extension ChainModel {
    func accountRequest() -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            addressPrefix: addressPrefix,
            isEthereumBased: isEthereumBased
        )
    }

    var accountIdSize: Int {
        switch chainFormat {
        case .substrate:
            return 32
        case .ethereum:
            return 20
        }
    }
}
