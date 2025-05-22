import Foundation

protocol WalletMigrationDestinationProtocol {
    func accept(with message: WalletMigrationMessage.Accepted) throws
}

final class WalletMigrationDestination {
    let originScheme: String
    let navigator: WalletMigrationLinkNavigating

    init(originScheme: String, navigator: WalletMigrationLinkNavigating = WalletMigrationLinkNavigator()) {
        self.originScheme = originScheme
        self.navigator = navigator
    }
}

private extension WalletMigrationDestination {
    func createAcceptedDeepLink(from message: WalletMigrationMessage.Accepted) throws -> URL {
        var components = URLComponents()
        components.scheme = originScheme
        components.host = WalletMigrationAction.migrateAccepted.rawValue

        components.queryItems = [
            URLQueryItem(
                name: WalletMigrationQueryKey.key.rawValue,
                value: message.destinationPublicKey.base64EncodedString()
            )
        ]

        guard let url = components.url else {
            throw WalletMigrationChannelError.invalidParameters
        }

        return url
    }
}

extension WalletMigrationDestination: WalletMigrationDestinationProtocol {
    func accept(with message: WalletMigrationMessage.Accepted) throws {
        let deepLink = try createAcceptedDeepLink(from: message)

        navigator.open(deepLink)
    }
}
