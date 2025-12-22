import Foundation
import WalletConnectPairing
import SubstrateSdk
import EthereumSignTypedDataUtil

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
        params: AnyCodable,
        method: WalletConnectMethod
    ) throws -> JSON {
        guard let walletAccountId = wallet.fetch(for: chain.accountRequest())?.accountId else {
            throw WalletConnectSignModelFactoryError.missingAccount(chainId: chain.chainId)
        }

        let json = try params.get(JSON.self)

        guard
            let requestAccountId = try? json.address?.stringValue?.toAccountId(
                using: chain.chainFormat
            ) else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: method
            )
        }

        guard walletAccountId == requestAccountId else {
            throw WalletConnectSignModelFactoryError.invalidAccount(
                expected: walletAccountId.toHex(includePrefix: true),
                actual: requestAccountId.toHex(includePrefix: true)
            )
        }

        return json
    }

    private static func createPolkadotSignTransaction(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable,
        method: WalletConnectMethod
    ) throws -> JSON {
        let json = try parseAndValidatePolkadotParams(
            for: wallet,
            chain: chain,
            params: params,
            method: method
        )

        guard let payload = try json.transactionPayload?.map(to: PolkadotExtensionExtrinsic.self) else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: method
            )
        }

        return try payload.toScaleCompatibleJSON()
    }

    private static func createPolkadotSignMessage(
        for wallet: MetaAccountModel,
        chain: ChainModel,
        params: AnyCodable,
        method: WalletConnectMethod
    ) throws -> JSON {
        let json = try parseAndValidatePolkadotParams(
            for: wallet,
            chain: chain,
            params: params,
            method: method
        )

        guard let messageJson = json.message, messageJson.stringValue != nil else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: method
            )
        }

        return messageJson
    }

    private static func createEthereumTransaction(for params: AnyCodable, method: WalletConnectMethod) throws -> JSON {
        let json = try params.get(JSON.self)

        guard
            let wcTransaction = try? json.arrayValue?.first?.map(
                to: WalletConnectEthereumTransaction.self
            ) else {
            throw WalletConnectSignModelFactoryError.invalidParams(
                params: json,
                method: method
            )
        }

        let transaction = EthereumTransaction(
            from: wcTransaction.from,
            to: wcTransaction.to,
            gas: wcTransaction.gasLimit?.toHexWithPrefix(),
            gasPrice: wcTransaction.gasPrice?.toHexWithPrefix(),
            value: wcTransaction.value?.toHexWithPrefix(),
            data: wcTransaction.data,
            nonce: wcTransaction.nonce?.toHexWithPrefix()
        )

        return try transaction.toScaleCompatibleJSON()
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

        guard let data = typedDataString.data(using: .utf8) else {
            throw CommonError.dataCorruption
        }

        let typeData = try JSONDecoder().decode(EIP712TypedData.self, from: data)
        let hash = try typeData.signableHash(version: .v4)

        return JSON.stringValue(hash.toHex(includePrefix: true))
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
                params: params,
                method: method
            )
        case .polkadotSignMessage:
            return try createPolkadotSignMessage(
                for: wallet,
                chain: chain,
                params: params,
                method: method
            )
        case .ethSignTransaction, .ethSendTransaction:
            return try createEthereumTransaction(for: params, method: method)
        case .ethPersonalSign:
            return try createPersonalSignMessage(
                for: wallet,
                chain: chain,
                params: params
            )
        case .ethSignTypeData, .ethSignTypeDataV4:
            return try createSignTypedDataMessage(
                for: wallet,
                chain: chain,
                params: params
            )
        }
    }

    static func createSigningType(
        for _: MetaAccountModel,
        chain: ChainModel,
        method: WalletConnectMethod
    ) throws -> DAppSigningType {
        switch method {
        case .polkadotSignTransaction:
            return .extrinsic(chain: chain)
        case .polkadotSignMessage:
            return .bytes(chain: chain)
        case .ethSendTransaction:
            return .ethereumSendTransaction(chain: .left(chain))
        case .ethSignTransaction:
            return .ethereumSignTransaction(chain: .left(chain))
        case .ethPersonalSign, .ethSignTypeData, .ethSignTypeDataV4:
            return .ethereumBytes(chain: .left(chain))
        }
    }

    static func createSigningResponse(
        for method: WalletConnectMethod,
        signature: Data,
        modifiedTransaction: Data?
    ) -> AnyCodable {
        switch method {
        case .polkadotSignTransaction, .polkadotSignMessage:
            let identifier = (0 ... UInt32.max).randomElement() ?? 0
            let result = PolkadotExtensionSignerResult(
                identifier: UInt(identifier),
                signature: signature.toHex(includePrefix: true),
                signedTransaction: modifiedTransaction?.toHex(includePrefix: true)
            )

            return AnyCodable(result)
        case .ethSignTransaction, .ethSendTransaction, .ethPersonalSign, .ethSignTypeData, .ethSignTypeDataV4:
            let result = signature.toHex(includePrefix: true)
            return AnyCodable(result)
        }
    }
}
