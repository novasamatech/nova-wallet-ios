import UIKit

protocol WalletMigrationLinkNavigating {
    func canOpenURL(_ url: URL) -> Bool
    func open(_ url: URL)
}

final class WalletMigrationLinkNavigator {}

extension WalletMigrationLinkNavigator: WalletMigrationLinkNavigating {
    func canOpenURL(_ url: URL) -> Bool {
        UIApplication.shared.canOpenURL(url)
    }

    func open(_ url: URL) {
        UIApplication.shared.open(url)
    }
}
