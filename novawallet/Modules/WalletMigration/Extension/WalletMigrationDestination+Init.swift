import Foundation
import UIKit
import Foundation_iOS

extension WalletMigrationDestination {
    static func createFrom(originScheme: String) -> WalletMigrationDestination {
        WalletMigrationDestination(
            originScheme: originScheme,
            queryFactory: WalletMigrationQueryFactory(),
            navigator: WalletMigrationLinkNavigator(application: UIApplication.shared)
        )
    }
}
