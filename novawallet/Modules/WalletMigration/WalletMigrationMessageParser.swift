import Foundation

enum WalletMigrationMessageParsingError: Error {
    case invalidURL(URL)
    case expectedQueryParam(String)
}

protocol WalletMigrationMessageParsing {
    func parseAction(from url: URL) -> WalletMigrationAction?
    func parseMessage(for action: WalletMigrationAction, from url: URL) throws -> WalletMigrationMessage
}

final class WalletMigrationMessageParser {}

private extension WalletMigrationMessageParser {
    func parseQueryItems(from url: URL) throws -> [URLQueryItem] {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            !queryItems.isEmpty else {
            throw WalletMigrationMessageParsingError.invalidURL(url)
        }

        return queryItems
    }

    func parseQueryItem<T>(
        by queryKey: WalletMigrationQueryKey,
        from items: [URLQueryItem],
        using mappingClosure: (String) throws -> T
    ) throws -> T {
        guard
            let item = items.first(where: { $0.name == queryKey.rawValue }),
            let value = item.value else {
            throw WalletMigrationMessageParsingError.expectedQueryParam(queryKey.rawValue)
        }

        return try mappingClosure(value)
    }

    func parseQueryItemString(
        by queryKey: WalletMigrationQueryKey,
        from items: [URLQueryItem]
    ) throws -> String {
        try parseQueryItem(by: queryKey, from: items, using: { $0 })
    }

    func parseStartMessage(from url: URL) throws -> WalletMigrationMessage {
        let queryItems = try parseQueryItems(from: url)

        let scheme = try parseQueryItemString(by: .scheme, from: queryItems)

        return .start(.init(originScheme: scheme))
    }

    func parseAcceptMessage(from url: URL) throws -> WalletMigrationMessage {
        let queryItems = try parseQueryItems(from: url)

        let pubKey: WalletMigrationKeypair.PublicKey = try parseQueryItem(
            by: .key,
            from: queryItems
        ) { value in
            try WalletMigrationKeypair.PublicKey(hexString: value)
        }

        return .accepted(.init(destinationPublicKey: pubKey))
    }

    func parseCompleteMessage(from url: URL) throws -> WalletMigrationMessage {
        let queryItems = try parseQueryItems(from: url)

        let pubKey: WalletMigrationKeypair.PublicKey = try parseQueryItem(
            by: .key,
            from: queryItems
        ) { value in
            try WalletMigrationKeypair.PublicKey(hexString: value)
        }

        let encryptedData: Data = try parseQueryItem(
            by: .encryptedData,
            from: queryItems
        ) { value in
            try Data(hexString: value)
        }

        let name = try? parseQueryItemString(by: .name, from: queryItems)

        let complete = WalletMigrationMessage.Complete(
            originPublicKey: pubKey,
            encryptedData: encryptedData,
            name: name
        )

        return WalletMigrationMessage.complete(complete)
    }
}

extension WalletMigrationMessageParser: WalletMigrationMessageParsing {
    func parseAction(from url: URL) -> WalletMigrationAction? {
        guard let host = url.host(percentEncoded: false) else {
            return nil
        }

        return WalletMigrationAction(rawValue: host)
    }

    func parseMessage(for action: WalletMigrationAction, from url: URL) throws -> WalletMigrationMessage {
        switch action {
        case .migrate:
            try parseStartMessage(from: url)
        case .migrateAccepted:
            try parseAcceptMessage(from: url)
        case .migrateComplete:
            try parseCompleteMessage(from: url)
        }
    }
}
