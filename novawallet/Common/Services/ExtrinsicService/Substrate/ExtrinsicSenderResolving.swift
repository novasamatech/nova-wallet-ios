import Foundation
import SubstrateSdk

enum ExtrinsicSenderResolution {
    struct ResolvedProxy {
        let proxyAccount: MetaChainAccountResponse
        let proxiedAccount: ChainAccountResponse
        let paths: [CallCodingPath: ProxyPathFinder.Path]
    }

    case current(ChainAccountResponse)
    case proxy(ResolvedProxy)

    var account: ChainAccountResponse {
        switch self {
        case let .current(account):
            return account
        case let .proxy(proxy):
            return proxy.proxyAccount.chainAccount
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
