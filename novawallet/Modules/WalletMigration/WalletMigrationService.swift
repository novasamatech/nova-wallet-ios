import Foundation

protocol WalletMigrationDelegate: AnyObject {
    func didReceiveMigration(message: WalletMigrationMessage)
}

protocol WalletMigrationServiceProtocol: URLHandlingServiceProtocol {
    var delegate: WalletMigrationDelegate? { get set }

    func consumePendingMessage() -> WalletMigrationMessage?
}

final class WalletMigrationService {
    let logger: LoggerProtocol

    weak var delegate: WalletMigrationDelegate?

    private var pendingMessage: WalletMigrationMessage?

    private let parser = WalletMigrationMessageParser()

    init(logger: LoggerProtocol) {
        self.logger = logger
    }
}

private extension WalletMigrationService {
    func markPendingMessageConsumed() {
        pendingMessage = nil
    }

    func handle(message: WalletMigrationMessage) {
        if let delegate {
            markPendingMessageConsumed()

            delegate.didReceiveMigration(message: message)
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

    func consumePendingMessage() -> WalletMigrationMessage? {
        let message = pendingMessage

        markPendingMessageConsumed()

        return message
    }
}
