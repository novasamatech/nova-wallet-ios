import Foundation
import Operation_iOS
import SubstrateSdk

protocol ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(for request: ParitySignerWallet, type: ParitySignerType) -> BaseOperation<MetaAccountModel>
}

final class ParitySignerWalletOperationFactory {}

private extension ParitySignerWalletOperationFactory {
    func newLegacyHardwareWalletFromSingle(
        name: String,
        format: ParitySignerWalletFormat.Single
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            switch format.scheme {
            case .substrate:
                let cryptoType = MultiassetCryptoType.sr25519.rawValue

                return MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: name,
                    substrateAccountId: format.accountId,
                    substrateCryptoType: cryptoType,
                    substratePublicKey: format.accountId,
                    ethereumAddress: nil,
                    ethereumPublicKey: nil,
                    chainAccounts: [],
                    type: .paritySigner
                )
            case .evm:
                return MetaAccountModel(
                    metaId: UUID().uuidString,
                    name: name,
                    substrateAccountId: nil,
                    substrateCryptoType: nil,
                    substratePublicKey: nil,
                    ethereumAddress: format.accountId,
                    ethereumPublicKey: format.publicKey,
                    chainAccounts: [],
                    type: .paritySigner
                )
            }
        }
    }

    func newConsensusBasedHardwareWalletFromSingle(
        name: String,
        format: ParitySignerWalletFormat.Single
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let cryptoType: MultiassetCryptoType = switch format.scheme {
            case .substrate:
                MultiassetCryptoType.sr25519
            case .evm:
                MultiassetCryptoType.ethereumEcdsa
            }

            let chainAccount = ChainAccountModel(
                chainId: format.genesisHash.toHex(),
                accountId: format.accountId,
                publicKey: format.publicKey ?? format.accountId, // TODO: Validate public key
                cryptoType: cryptoType.rawValue,
                proxy: nil
            )

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: nil,
                substrateCryptoType: nil,
                substratePublicKey: nil,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [chainAccount],
                type: .polkadotVault
            )
        }
    }

    func newHardwareWalletFromSingle(
        name: String,
        format: ParitySignerWalletFormat.Single,
        type: ParitySignerType
    ) -> BaseOperation<MetaAccountModel> {
        switch type {
        case .legacy:
            return newLegacyHardwareWalletFromSingle(name: name, format: format)
        case .vault:
            return newConsensusBasedHardwareWalletFromSingle(name: name, format: format)
        }
    }

    func newHardwareWalletRootKeys(
        name: String,
        format: ParitySignerWalletFormat.RootKeys
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let ethereumAddress = try format.ethereum.publicKeyData.ethereumAddressFromPublicKey()
            let substrateAccountId = try format.substrate.publicKeyData.publicKeyToAccountId()

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: format.substrate.type.multiassetType.rawValue,
                substratePublicKey: format.substrate.publicKeyData,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: format.ethereum.publicKeyData,
                chainAccounts: [],
                type: .polkadotVaultRoot
            )
        }
    }
}

extension ParitySignerWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(
        for request: ParitySignerWallet,
        type: ParitySignerType
    ) -> BaseOperation<MetaAccountModel> {
        switch request.format {
        case let .single(singleAddress):
            newHardwareWalletFromSingle(
                name: request.name,
                format: singleAddress,
                type: type
            )
        case let .rootKeys(rootKeys):
            newHardwareWalletRootKeys(name: request.name, format: rootKeys)
        }
    }
}

extension ParitySignerType {
    var walletType: MetaAccountModelType {
        switch self {
        case .legacy:
            return .paritySigner
        case .vault:
            return .polkadotVault
        }
    }
}
