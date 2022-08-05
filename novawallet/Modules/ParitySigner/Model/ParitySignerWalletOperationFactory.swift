import Foundation
import RobinHood

protocol ParitySignerWalletOperationFactoryProtocol {
    func newParitySignerWallet(for request: ParitySignerWallet) -> BaseOperation<MetaAccountModel>
}

final class ParitySignerWalletOperationFactory: ParitySignerWalletOperationFactoryProtocol {
    func newParitySignerWallet(for request: ParitySignerWallet) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let cryptoType = MultiassetCryptoType.sr25519.rawValue

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.name,
                substrateAccountId: request.substrateAccountId,
                substrateCryptoType: cryptoType,
                substratePublicKey: request.substrateAccountId,
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: [],
                type: .paritySigner
            )
        }
    }
}
