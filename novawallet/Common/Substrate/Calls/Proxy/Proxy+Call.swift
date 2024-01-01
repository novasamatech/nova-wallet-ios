import Foundation
import SubstrateSdk

extension Proxy {
    struct ProxyCall: Codable {
        enum CodingKeys: String, CodingKey {
            case real
            case forceProxyType = "force_proxy_type"
            case call
        }

        @BytesCodable var real: AccountId
        let forceProxyType: Proxy.ProxyType?
        let call: JSON

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(moduleName: Proxy.moduleName, callName: "proxy", args: self)
        }
    }
}
