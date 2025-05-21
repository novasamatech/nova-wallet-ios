import Foundation
@testable import novawallet

final class MockWalletMigrationLinkNavigator {
    private(set) var lastOpenedLink: URL?
}

extension MockWalletMigrationLinkNavigator: WalletMigrationLinkNavigating {
    func canOpenURL(_ url: URL) -> Bool {
        true
    }

    func open(_ url: URL) {
        lastOpenedLink = url
    }
}
