import Foundation

extension Proxy {
    static var proxyList: StorageCodingPath {
        .init(moduleName: Proxy.name, itemName: "Proxies")
    }
}

extension Proxy {
    static var depositBase: ConstantCodingPath {
        .init(moduleName: Proxy.name, constantName: "ProxyDepositBase")
    }

    static var depositFactor: ConstantCodingPath {
        .init(moduleName: Proxy.name, constantName: "ProxyDepositFactor")
    }

    static var maxProxyCount: ConstantCodingPath {
        .init(moduleName: Proxy.name, constantName: "MaxProxies")
    }
}
