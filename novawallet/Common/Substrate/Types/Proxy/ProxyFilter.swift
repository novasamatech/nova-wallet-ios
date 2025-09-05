import Foundation

enum ProxyFilter {
    static func filteredStakingProxy(from proxy: ProxyDefinition) -> ProxyDefinition {
        ProxyDefinition(definition: proxy.definition.filter { $0.proxyType == .staking })
    }

    static func allProxies(from proxy: ProxyDefinition) -> ProxyDefinition {
        proxy
    }
}
