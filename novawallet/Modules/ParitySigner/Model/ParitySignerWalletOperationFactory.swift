import Foundation
import Operation_iOS
import SubstrateSdk

protocol ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(for request: ParitySignerWallet, type: ParitySignerType) -> BaseOperation<MetaAccountModel>
}

final class ParitySignerWalletOperationFactory {}

private extension ParitySignerWalletOperationFactory {
    func newHardwareWalletFromSignle(
        name: String,
        format: ParitySignerWalletFormat.Single,
        type: ParitySignerType
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let cryptoType = MultiassetCryptoType.sr25519.rawValue

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: name,
                substrateAccountId: format.substrateAccountId,
                substrateCryptoType: cryptoType,
                substratePublicKey: format.substrateAccountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: type.walletType
            )
        }
    }

    func newHardwareWalletRootKeys(
        name: String,
        format: ParitySignerWalletFormat.RootKeys,
        type: ParitySignerType
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
                type: type.walletType
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
            newHardwareWalletFromSignle(
                name: request.name,
                format: singleAddress,
                type: type
            )
        case let .rootKeys(rootKeys):
            newHardwareWalletRootKeys(
                name: request.name,
                format: rootKeys,
                type: type
            )
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
