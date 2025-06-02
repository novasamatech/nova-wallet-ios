import Foundation
import Keystore_iOS

enum URLHandlingPendingLink: Codable {
    case staking
    case governance(Referenda.ReferendumIndex)
    case dApp(URL)
    case card(String?)
}

protocol URLHandlingStoreProtocol {
    func save(pendingLink: URLHandlingPendingLink) throws
    func getPendingLink() -> URLHandlingPendingLink?
    func clearPendingLink()
}

final class URLHandlingPersistentStore {
    static let pendingLinkKey = "com.novawallet.pendingDeepLink"

    let settings: SettingsManagerProtocol

    init(settings: SettingsManagerProtocol) {
        self.settings = settings
    }
}

extension URLHandlingPersistentStore: URLHandlingStoreProtocol {
    func save(pendingLink: URLHandlingPendingLink) throws {
        settings.set(value: pendingLink, for: Self.pendingLinkKey)
    }

    func getPendingLink() -> URLHandlingPendingLink? {
        settings.value(of: URLHandlingPendingLink.self, for: Self.pendingLinkKey)
    }

    func clearPendingLink() {
        settings.removeValue(for: Self.pendingLinkKey)
    }
}
