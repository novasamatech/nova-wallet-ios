import UIKit

protocol WalletMigrationOriginProtocol {
    func start(with message: WalletMigrationMessage.Start) throws
    func complete(with message: WalletMigrationMessage.Complete) throws
}

final class WalletMigrationOrigin {
    let navigator: WalletMigrationLinkNavigating

    let destinationAppLinkURL: URL
    let destinationScheme: String

    init(
        destinationAppLinkURL: URL,
        destinationScheme: String,
        navigator: WalletMigrationLinkNavigating = WalletMigrationLinkNavigator()
    ) {
        self.destinationAppLinkURL = destinationAppLinkURL
        self.destinationScheme = destinationScheme
        self.navigator = navigator
    }
}

private extension WalletMigrationOrigin {
    func createStartAppLink(for message: WalletMigrationMessage.Start) throws -> URL {
        guard var components = URLComponents(url: destinationAppLinkURL, resolvingAgainstBaseURL: false) else {
            throw WalletMigrationChannelError.invalidDestinationURL
        }

        components.queryItems = [
            URLQueryItem(name: ExternalUniversalLink.actionKey, value: WalletMigrationAction.migrate.rawValue),
            URLQueryItem(name: WalletMigrationQueryKey.scheme.rawValue, value: message.originScheme)
        ]

        guard let url = components.url else {
            throw WalletMigrationChannelError.invalidParameters
        }

        return url
    }

    func createStartDeepLink(for message: WalletMigrationMessage.Start) throws -> URL {
        var components = URLComponents()
        components.scheme = destinationScheme
        components.host = WalletMigrationAction.migrate.rawValue

        components.queryItems = [
            URLQueryItem(name: WalletMigrationQueryKey.scheme.rawValue, value: message.originScheme)
        ]

        guard let url = components.url else {
            throw WalletMigrationChannelError.invalidParameters
        }

        return url
    }

    func createCompleteDeepLink(for message: WalletMigrationMessage.Complete) throws -> URL {
        var components = URLComponents()
        components.scheme = destinationScheme
        components.host = WalletMigrationAction.migrateComplete.rawValue

        var queryItems = [
            URLQueryItem(name: WalletMigrationQueryKey.key.rawValue, value: message.originPublicKey.toHex()),
            URLQueryItem(name: WalletMigrationQueryKey.encryptedData.rawValue, value: message.encryptedData.toHex()),
        ]

        if let name = message.name {
            queryItems.append(
                URLQueryItem(name: WalletMigrationQueryKey.name.rawValue, value: name)
            )
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw WalletMigrationChannelError.invalidParameters
        }

        return url
    }
}

extension WalletMigrationOrigin: WalletMigrationOriginProtocol {
    func start(with message: WalletMigrationMessage.Start) throws {
        let deepLink = try createStartDeepLink(for: message)

        guard !navigator.canOpenURL(deepLink) else {
            navigator.open(deepLink)
            return
        }

        let appLink = try createStartAppLink(for: message)

        navigator.open(appLink)
    }

    func complete(with message: WalletMigrationMessage.Complete) throws {
        let deepLink = try createCompleteDeepLink(for: message)

        navigator.open(deepLink)
    }
}
