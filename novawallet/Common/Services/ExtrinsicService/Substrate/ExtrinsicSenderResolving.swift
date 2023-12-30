import Foundation
import SubstrateSdk

enum ExtrinsicSenderResolution {
    struct ResolvedProxy {
        let proxyAccount: ChainAccountResponse
        let proxiedAccount: ChainAccountResponse
        let type: Proxy.ProxyType
    }

    case current(ChainAccountResponse)
    case proxy(ResolvedProxy)

    var account: ChainAccountResponse {
        switch self {
        case let .current(account):
            return account
        case let .proxy(proxy):
            return proxy.proxyAccount
        }
    }
}

typealias ExtrinsicSenderBuilderResolution = (sender: ExtrinsicSenderResolution, builders: [ExtrinsicBuilderProtocol])

protocol ExtrinsicSenderResolving: AnyObject {
    func resolveSender(wrapping builders: [ExtrinsicBuilderProtocol]) throws -> ExtrinsicSenderBuilderResolution
}

final class ExtrinsicCurrentSenderResolver: ExtrinsicSenderResolving {
    let currentAccount: ChainAccountResponse

    init(currentAccount: ChainAccountResponse) {
        self.currentAccount = currentAccount
    }

    func resolveSender(wrapping builders: [ExtrinsicBuilderProtocol]) throws -> ExtrinsicSenderBuilderResolution {
        (.current(currentAccount), builders)
    }
}
