import Foundation
import SubstrateSdk

extension Proxy {
    struct ProxyCall: Codable {
        enum CodingKeys: String, CodingKey {
            case real
            case forceProxyType = "force_proxy_type"
            case call
        }

        let real: MultiAddress
        let forceProxyType: Proxy.ProxyType?
        let call: JSON

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: Proxy.name, callName: "proxy", args: self)
        }
    }

    struct AddProxyCall: Codable {
        enum CodingKeys: String, CodingKey {
            case proxy = "delegate"
            case proxyType = "proxy_type"
            case delay
        }

        let proxy: MultiAddress
        let proxyType: ProxyType
        @StringCodable var delay: BlockNumber
    }
}
