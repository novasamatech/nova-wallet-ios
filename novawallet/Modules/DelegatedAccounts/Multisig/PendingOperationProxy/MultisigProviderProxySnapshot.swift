import Foundation

protocol MultisigProviderProxySnapshotApplicable: AnyObject {
    var formattingCache: InMemoryCache<Substrate.CallHash, FormattedCall> { get set }
}

protocol MultisigProviderProxySnapshotProtocol {
    func apply(to proxy: MultisigProviderProxySnapshotApplicable)
}

struct MultisigProviderProxySnapshot: MultisigProviderProxySnapshotProtocol {
    let formattingCache: InMemoryCache<Substrate.CallHash, FormattedCall>

    func apply(to proxy: MultisigProviderProxySnapshotApplicable) {
        proxy.formattingCache = formattingCache
    }
}
