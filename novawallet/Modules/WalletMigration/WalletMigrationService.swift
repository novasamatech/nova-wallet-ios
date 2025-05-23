import Foundation

protocol WalletMigrationObserver: AnyObject {
    func didReceiveMigration(message: WalletMigrationMessage)
}

protocol WalletMigrationServiceProtocol: URLHandlingServiceProtocol {
    func addObserver(_ observer: WalletMigrationObserver)
    func removeObserver(_ observer: WalletMigrationObserver)

    func consumePendingMessage() -> WalletMigrationMessage?
}

final class WalletMigrationService {
    let logger: LoggerProtocol

    private var observers: [WeakWrapper] = []

    private var pendingMessage: WalletMigrationMessage?

    private let parser: WalletMigrationMessageParser

    init(localDeepLinkScheme: String, logger: LoggerProtocol) {
        parser = WalletMigrationMessageParser(localDeepLinkScheme: localDeepLinkScheme)
        self.logger = logger
    }
}

private extension WalletMigrationService {
    func markPendingMessageConsumed() {
        pendingMessage = nil
    }

    func handle(message: WalletMigrationMessage) {
        observers.clearEmptyItems()

        if !observers.isEmpty {
            markPendingMessageConsumed()

            observers.forEach { ($0.target as? WalletMigrationObserver)?.didReceiveMigration(message: message) }
        } else {
            pendingMessage = message
        }
    }
}

extension WalletMigrationService: WalletMigrationServiceProtocol {
    func handle(url: URL) -> Bool {
        guard
            let action = parser.parseAction(from: url) else {
            return false
        }

        do {
            let message = try parser.parseMessage(for: action, from: url)

            handle(message: message)
        } catch {
            logger.error("Can't create message for action \(action)")
        }

        return true
    }

    func addObserver(_ observer: WalletMigrationObserver) {
        observers.clearEmptyItems()

        if !observers.contains(where: { $0.target === observer }) {
            observers.append(.init(target: observer))
        }
    }

    func removeObserver(_ observer: WalletMigrationObserver) {
        observers.clearEmptyItems()

        observers = observers.filter { $0.target !== observer }
    }

    func consumePendingMessage() -> WalletMigrationMessage? {
        let message = pendingMessage

        markPendingMessageConsumed()

        return message
    }
}
