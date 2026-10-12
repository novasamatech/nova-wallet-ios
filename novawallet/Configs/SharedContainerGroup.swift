import Foundation
import NovaAuth

enum SharedContainerGroup {
    static var name: String {
        #if F_RELEASE
            return "group.novafoundation.novawallet"
        #else
            return "group.novafoundation.novawallet.dev"
        #endif
    }
}

extension SharedContainerGroup {
    static var novaAuthStore: NovaAuthSharedStoreConfiguration? {
        guard let hostAppNamespace = Bundle.main.object(forInfoDictionaryKey: "NovaAuthHostAppNamespace") as? String else {
            return nil
        }
        return try? NovaAuthSharedStoreConfiguration(
            accessGroup: name,
            hostAppNamespace: hostAppNamespace
        )
    }
}
