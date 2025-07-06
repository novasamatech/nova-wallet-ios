import Foundation
import SubstrateSdk

enum ExtrinsicSenderResolution {
    struct ResolutionDelegateFailure {
        let callPath: CallCodingPath
        let paths: DelegationResolution.GraphResult
    }

    struct ResolvedDelegate {
        let delegateAccount: MetaChainAccountResponse?
        let delegatedAccount: ChainAccountResponse
        let path: DelegationResolution.PathFinderPath?
        let allWallets: [MetaAccountModel]
        let chain: ChainModel
        let failures: [ResolutionDelegateFailure]
    }

    case current(ChainAccountResponse)
    case delegate(ResolvedDelegate)

    var account: ChainAccountResponse {
        switch self {
        case let .current(account):
            return account
        case let .delegate(delegate):
            return delegate.delegateAccount?.chainAccount ?? delegate.delegatedAccount
        }
    }
}

typealias ExtrinsicSenderBuilderResolution = (sender: ExtrinsicSenderResolution, builders: [ExtrinsicBuilderProtocol])

protocol ExtrinsicSenderResolving: AnyObject {
    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution
}

final class ExtrinsicCurrentSenderResolver: ExtrinsicSenderResolving {
    let currentAccount: ChainAccountResponse

    init(currentAccount: ChainAccountResponse) {
        self.currentAccount = currentAccount
    }

    func resolveSender(
        wrapping builders: [ExtrinsicBuilderProtocol],
        codingFactory _: RuntimeCoderFactoryProtocol
    ) throws -> ExtrinsicSenderBuilderResolution {
        (.current(currentAccount), builders)
    }
}
