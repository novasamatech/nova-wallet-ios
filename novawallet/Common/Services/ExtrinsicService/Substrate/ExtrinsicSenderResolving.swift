import Foundation
import SubstrateSdk

enum ExtrinsicSenderResolution {
    case current
    case proxy(MetaAccountModel, Proxy.ProxyType)
}

protocol ExtrinsicSenderResolving: AnyObject {
    func resolve(for calls: [JSON]) throws -> ExtrinsicSenderResolution
}

final class ExtrinsicProxySenderResolver {
    let wallets: [MetaAccountModel]

    init(wallets: [MetaAccountModel]) {
        self.wallets = wallets
    }
}

extension ExtrinsicProxySenderResolver: ExtrinsicSenderResolving {
    func resolve(for _: [JSON]) throws -> ExtrinsicSenderResolution {
        .current
    }
}

final class ExtrinsicCurrentSenderResolver: ExtrinsicSenderResolving {
    func resolve(for _: [JSON]) throws -> ExtrinsicSenderResolution {
        .current
    }
}
