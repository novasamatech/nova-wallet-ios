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

        static var callPath: CallCodingPath {
            CallCodingPath(moduleName: Proxy.name, callName: "proxy")
        }

        func runtimeCall() -> RuntimeCall<Self> {
            RuntimeCall(
                moduleName: Self.callPath.moduleName,
                callName: Self.callPath.callName,
                args: self
            )
        }
    }
}
