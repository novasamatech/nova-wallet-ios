import Foundation
import RobinHood

protocol ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(for request: ParitySignerWallet, type: ParitySignerType) -> BaseOperation<MetaAccountModel>
}

final class ParitySignerWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol {
    func newHardwareWallet(
        for request: ParitySignerWallet,
        type: ParitySignerType
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let cryptoType = MultiassetCryptoType.sr25519.rawValue
            let signingType = type

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.name,
                substrateAccountId: request.substrateAccountId,
                substrateCryptoType: cryptoType,
                substratePublicKey: request.substrateAccountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: type.walletType
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
