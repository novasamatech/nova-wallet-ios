import Foundation
import RobinHood

protocol WatchOnlyWalletOperationFactoryProtocol {
    func newWatchOnlyWalletOperation(for request: WatchOnlyWallet) -> BaseOperation<MetaAccountModel>
}

final class WatchOnlyWalletOperationFactory: WatchOnlyWalletOperationFactoryProtocol {
    func newWatchOnlyWalletOperation(for request: WatchOnlyWallet) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let substrateAccountId = try request.substrateAddress.toAccountId()
            let evmAddress = try request.evmAddress?.toAccountId()

            return MetaAccountModel(
                metaId: UUID().uuidString,
                name: request.name,
                substrateAccountId: substrateAccountId,
                substrateCryptoType: 0,
                substratePublicKey: substrateAccountId,
                ethereumAddress: evmAddress,
                ethereumPublicKey: evmAddress,
                chainAccounts: [],
                type: .watchOnly
            )
        }
    }
}
