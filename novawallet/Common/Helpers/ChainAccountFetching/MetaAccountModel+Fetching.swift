import Foundation

extension MetaAccountModel {
    func fetchOrError(for request: ChainAccountRequest) throws -> ChainAccountResponse {
        guard let response = fetch(for: request) else {
            throw ChainAccountFetchingError.accountNotExists
        }

        return response
    }

    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        switch type {
        case .genericLedger:
            if request.supportsGenericLedger {
                return executeFetch(request: request)
            } else {
                return nil
            }
        case .polkadotVaultRoot:
            if request.hasSubstrateRuntime {
                return executeFetch(request: request)
            } else {
                return nil
            }
        case .polkadotVault:
            return executeConsensusBasedFetch(request: request)
        case .secrets, .ledger, .paritySigner, .proxied, .watchOnly:
            return executeFetch(request: request)
        }
    }

    func hasAccount(in chain: ChainModel) -> Bool {
        fetch(for: chain.accountRequest()) != nil
    }

    // Note that this query might return an account in another chain if it can't be found for provided chain
    func fetchByAccountId(_ accountId: AccountId, request: ChainAccountRequest) -> ChainAccountResponse? {
        if
            let chainAccount = chainAccounts.first(
                where: { $0.chainId == request.chainId && $0.accountId == accountId }
            ),
            let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) {
            return ChainAccountResponse(
                metaId: metaId,
                chainId: chainAccount.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true,
                type: type
            )
        }

        if
            request.isEthereumBased,
            let publicKey = ethereumPublicKey,
            let ethereumAccountId = ethereumAddress,
            ethereumAccountId == accountId {
            return ChainAccountResponse(
                metaId: metaId,
                chainId: request.chainId,
                accountId: ethereumAccountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false,
                type: type
            )
        }

        if
            !request.isEthereumBased,
            let substrateAccountId = substrateAccountId,
            let substratePublicKey = substratePublicKey,
            let substrateCryptoType = substrateCryptoType,
            substrateAccountId == accountId,
            let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) {
            return ChainAccountResponse(
                metaId: metaId,
                chainId: request.chainId,
                accountId: substrateAccountId,
                publicKey: substratePublicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: false,
                isChainAccount: false,
                type: type
            )
        }

        // if we can't match by chain still try to find account connected to another chain
        if
            let chainAccount = chainAccounts.first(where: { $0.accountId == accountId }),
            let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) {
            return ChainAccountResponse(
                metaId: metaId,
                chainId: chainAccount.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true,
                type: type
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
                isChainAccount: true,
                type: type
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
            isChainAccount: false,
            type: type
        )
    }

    func fetchMetaChainAccount(for request: ChainAccountRequest) -> MetaChainAccountResponse? {
        fetch(for: request).map {
            MetaChainAccountResponse(
                metaId: metaId,
                substrateAccountId: substrateAccountId,
                ethereumAccountId: ethereumAddress,
                walletIdenticonData: walletIdenticonData(),
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

    func has(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == chainId }) {
            return chainAccount.accountId == accountId
        } else {
            return substrateAccountId == accountId || ethereumAddress == accountId
        }
    }

    func isProxied(accountId: AccountId, chainId: ChainModel.Id) -> Bool {
        type == .proxied && has(accountId: accountId, chainId: chainId)
    }

    func proxyChainAccount(
        chainId: ChainModel.Id
    ) -> ChainAccountModel? {
        chainAccounts.first { $0.chainId == chainId && $0.proxy != nil }
    }

    func proxy() -> ProxyAccountModel? {
        guard type == .proxied,
              let chainAccount = chainAccounts.first(where: { $0.proxy != nil }) else {
            return nil
        }

        return chainAccount.proxy
    }

    func address(for chainAsset: ChainAsset) throws -> AccountAddress? {
        let request = chainAsset.chain.accountRequest()
        return fetch(for: request)?.toAddress()
    }
}

extension MetaAccountModel {
    private func getChainAccount(for chainId: ChainModel.Id) -> ChainAccountModel? {
        chainAccounts.first(where: { $0.chainId == chainId })
    }

    private func hasChainAccount(for chainId: ChainModel.Id) -> Bool {
        getChainAccount(for: chainId) != nil
    }

    private func executeFetchByChainAccount(
        _ chainId: ChainModel.Id,
        properties: ChainAccountRequest.Properties
    ) -> ChainAccountResponse? {
        guard let chainAccount = getChainAccount(for: chainId) else {
            return nil
        }

        guard let cryptoType = MultiassetCryptoType(rawValue: chainAccount.cryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            metaId: metaId,
            chainId: chainId,
            accountId: chainAccount.accountId,
            publicKey: chainAccount.publicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: properties.addressPrefix,
            isEthereumBased: properties.isEthereumBased,
            isChainAccount: true,
            type: type
        )
    }

    private func executeFetch(request: ChainAccountRequest) -> ChainAccountResponse? {
        if hasChainAccount(for: request.chainId) {
            return executeFetchByChainAccount(request.chainId, properties: request.properties)
        }

        if request.isEthereumBased {
            guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
                return nil
            }

            return ChainAccountResponse(
                metaId: metaId,
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                name: name,
                cryptoType: MultiassetCryptoType.ethereumEcdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false,
                type: type
            )
        }

        guard
            let substrateCryptoType = substrateCryptoType,
            let substrateAccountId = substrateAccountId,
            let substratePublicKey = substratePublicKey,
            let cryptoType = MultiassetCryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            metaId: metaId,
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            type: type
        )
    }

    private func executeConsensusBasedFetch(request: ChainAccountRequest) -> ChainAccountResponse? {
        if let response = executeFetch(request: request) {
            return response
        }

        // use the same account from relay chain if possible
        if
            !request.isEthereumBased,
            let parentId = request.parentId {
            return executeFetchByChainAccount(parentId, properties: request.properties)
        }

        return nil
    }
}
