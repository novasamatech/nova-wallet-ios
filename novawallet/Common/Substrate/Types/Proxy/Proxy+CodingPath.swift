import Foundation

extension Proxy {
    static func proxyList(for moduleName: String) -> ConstantCodingPath {
        .init(moduleName: moduleName, constantName: "proxies")
    }
}
