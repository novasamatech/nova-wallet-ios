import Foundation
import NovaAuth

extension ApplicationConfig {
    var novaAuthAppIdentity: NovaAuthAppIdentity? {
        let rawPrefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String
        let prefix = rawPrefix?.trimmingCharacters(in: CharacterSet(charactersIn: ". ")) ?? ""

        guard !prefix.isEmpty, let bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }

        do {
            return try NovaAuthAppIdentity(
                appID: prefix + "." + bundleId,
                environment: novaAuthEnvironment,
                version: version
            )
        } catch {
            Logger.shared.error("NovaAuth app identity rejected: \(error)")
            return nil
        }
    }

    private var novaAuthEnvironment: NovaAuthEnvironment {
        #if F_DEV
            .development
        #else
                .production
        #endif
    }
}
