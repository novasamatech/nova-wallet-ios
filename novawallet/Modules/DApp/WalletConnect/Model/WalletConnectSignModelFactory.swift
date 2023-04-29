import Foundation
import WalletConnectSwiftV2
import SubstrateSdk

enum WalletConnectSignModelFactoryError: Error {
    case missingAccount(chainId: ChainModel.Id)
    case invalidParams(params: JSON, method: WalletConnectMethod)
    case invalidChain(expected: ChainModel.Id, actual: ChainModel.Id)
    case invalidAccount(expected: AccountAddress, actual: AccountAddress)
}

enum WalletConnectSignModelFactory {
    private static func parseAndValidatePolkadotParams(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable
    ) throws -> JSON {
        guard let walletAddress = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw WalletConnectSignModelFactoryError.missingAccount(chainId: chain.chainId)
        }

        let json = try params.get(JSON.self)

        guard let requestAddress = json.address?.stringValue else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        // Wallet Connect can include addresses without checksum

        guard walletAddress.lowercased() == requestAddress.lowercased() else {
            throw WalletConnectSignModelFactoryError.invalidAccount(
                expected: walletAddress,
                actual: requestAddress
            )
        }

        return json
    }

    private static func createPolkadotSignTransaction(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable
    ) throws -> JSON {
        let json = try parseAndValidatePolkadotParams(
            for: wallet,
            chain: chain,
            params: params
        )

        guard
            let payload = try json.transactionPayload?.map(to: PolkadotExtensionExtrinsic.self),
            let address = wallet.fetch(for: chain.accountRequest())?.toAddress() else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        // Wallet Connect can include address without checksum, we manually add it for consistency

        let modifiedPayload = PolkadotExtensionExtrinsic(
            address: address,
            blockHash: payload.blockHash,
            blockNumber: payload.blockNumber,
            era: payload.era,
            genesisHash: payload.genesisHash,
            method: payload.method,
            nonce: payload.nonce,
            specVersion: payload.specVersion,
            tip: payload.tip,
            transactionVersion: payload.transactionVersion,
            signedExtensions: payload.signedExtensions,
            version: payload.version
        )

        return try modifiedPayload.toScaleCompatibleJSON()
    }

    private static func createPolkadotSignMessage(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable
    ) throws -> JSON {
        let json = try parseAndValidatePolkadotParams(
            for: wallet,
            chain: chain,
            params: params
        )

        guard let messageJson = json.message, messageJson.stringValue != nil else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        return messageJson
    }

    private static func createEthereumTransaction(for params: AnyCodable) throws -> JSON {
        let json = try params.get(JSON.self)

        guard let transaction = json.arrayValue?.first else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        return transaction
    }

    private static func parseAndValidateEthereumParams(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable,
        accountIndex: Int
    ) throws -> JSON {
        guard let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            throw WalletConnectSignModelFactoryError.missingAccount(chainId: chain.chainId)
        }

        let json = try params.get(JSON.self)

        guard
            let arrayParams = json.arrayValue,
            let txAccountId = try? arrayParams[safe: accountIndex]?.stringValue?.toAccountId(
                using: chain.chainFormat
            ) else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        guard accountId == txAccountId else {
            throw WalletConnectSignModelFactoryError.invalidAccount(
                expected: try accountId.toAddress(using: chain.chainFormat),
                actual: try txAccountId.toAddress(using: chain.chainFormat)
            )
        }

        return json
    }

    private static func createPersonalSignMessage(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable
    ) throws -> JSON {
        let json = try parseAndValidateEthereumParams(
            for: wallet,
            chain: chain,
            params: params,
            accountIndex: 1
        )

        guard
            let hexString = json.arrayValue?.first?.stringValue,
            let signingHashedData = try? Data(
                hexString: hexString
            ).ethereumPersonalSignMessage()?.keccak256() else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        return JSON.stringValue(signingHashedData.toHex(includePrefix: true))
    }

    private static func createSignTypedDataMessage(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable
    ) throws -> JSON {
        let json = try parseAndValidateEthereumParams(
            for: wallet,
            chain: chain,
            params: params,
            accountIndex: 0
        )

        guard let typedDataString = json.arrayValue?.last?.stringValue else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: .polkadotSignTransaction
            )
        }

        let isHex = typedDataString.isHex()

        guard !isHex else {
            return JSON.stringValue(typedDataString)
        }

        throw WalletConnectSignModelFactoryError.invalidParams(
            params: json,
            method: .polkadotSignTransaction
        )
    }
}

extension WalletConnectSignModelFactory {
    static func createOperationData(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable,
        method: WalletConnectMethod
    ) throws -> JSON {
        switch method {
        case .polkadotSignTransaction:
            return try createPolkadotSignTransaction(
                for: wallet,
                chain: chain,
                params: params
            )
        case .polkadotSignMessage:
            return try createPolkadotSignMessage(
                for: wallet,
                chain: chain,
                params: params
            )
        case .ethSignTransaction, .ethSendTransaction:
            return try createEthereumTransaction(for: params)
        case .ethPersonalSign:
            return try createPersonalSignMessage(
                for: wallet,
                chain: chain,
                params: params
            )
        case .ethSignTypeData:
            return try createSignTypedDataMessage(
                for: wallet,
                chain: chain,
                params: params
            )
        }
    }

    static func createSigningType(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        method: WalletConnectMethod
    ) throws -> DAppSigningType {
        switch method {
        case .polkadotSignTransaction:
            return .extrinsic(chain: chain)
        case .polkadotSignMessage:
            return .bytes(chain: chain)
        case .ethSendTransaction:
            guard let metamaskChain = MetamaskChain(chain: chain) else {
                throw CommonError.dataCorruption
            }

            return .ethereumSendTransaction(chain: metamaskChain)
        case .ethSignTransaction:
            guard let metamaskChain = MetamaskChain(chain: chain) else {
                throw CommonError.dataCorruption
            }

            return .ethereumSignTransaction(chain: metamaskChain)
        case .ethPersonalSign, .ethSignTypeData:
            guard
                let metamaskChain = MetamaskChain(chain: chain),
                let accountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
                throw CommonError.dataCorruption
            }

            return .ethereumBytes(chain: metamaskChain, accountId: accountId)
        }
    }
}
