import Foundation

enum DelegatedCallWrapperFactoryError: Error {
    case unsupportedDelegatedAccount(ChainAccountResponse)
}

enum DelegatedCallWrapperFactory {
    static func createCallWrapper(
        for delegatedAccount: ChainAccountResponse,
        delegateAccountId: AccountId
    ) throws -> DelegationResolutionCallWrapperProtocol {
        switch delegatedAccount.type {
        case .multisig:
            MultisigResolutionCallWrapper(delegatedAccount: delegatedAccount)
        case .proxied:
            ProxyResolutionCallWrapper(
                delegatedAccount: delegatedAccount,
                delegateAccountId: delegateAccountId
            )
        case .secrets,
             .genericLedger,
             .ledger,
             .paritySigner,
             .polkadotVault,
             .watchOnly:
            throw DelegatedCallWrapperFactoryError.unsupportedDelegatedAccount(
                delegatedAccount
            )
        }
    }
}
