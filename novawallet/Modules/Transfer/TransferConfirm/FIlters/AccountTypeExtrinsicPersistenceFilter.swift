import Foundation

final class AccountTypeExtrinsicPersistenceFilter {}

extension AccountTypeExtrinsicPersistenceFilter: ExtrinsicPersistenceFilterProtocol {
    func canPersistExtrinsic(for sender: ChainAccountResponse) -> Bool {
        sender.type != .multisig
    }
}
