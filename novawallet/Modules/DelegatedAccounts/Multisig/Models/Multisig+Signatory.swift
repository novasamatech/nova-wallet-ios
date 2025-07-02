import Foundation

extension Multisig {
    struct RemoteSignatory {
        let accountId: AccountId
    }

    struct LocalSignatory {
        let metaAccount: MetaChainAccountResponse
    }

    enum Signatory {
        case local(LocalSignatory)
        case remote(RemoteSignatory)

        var accountId: AccountId {
            switch self {
            case let .local(model):
                model.metaAccount.chainAccount.accountId
            case let .remote(model):
                model.accountId
            }
        }

        var localAccount: MetaChainAccountResponse? {
            switch self {
            case let .local(signatory):
                signatory.metaAccount
            case .remote:
                nil
            }
        }
    }
}

extension Array where Element == Multisig.Signatory {
    func findSignatory(for wallet: MetaAccountModel) -> Multisig.Signatory? {
        guard let multisig = wallet.multisigAccount?.multisig else {
            return nil
        }

        return findSignatory(by: multisig.signatory)
    }

    func findSignatory(by accountId: AccountId) -> Multisig.Signatory? {
        first { $0.accountId == accountId }
    }
}
