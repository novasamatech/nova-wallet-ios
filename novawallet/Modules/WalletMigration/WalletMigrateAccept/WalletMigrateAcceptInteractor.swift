import UIKit

final class WalletMigrateAcceptInteractor {
    weak var presenter: WalletMigrateAcceptInteractorOutputProtocol?
    
    let sessionManager: SecureSessionManaging
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol
    
    private var originScheme: String
    
    init(
        startMessage: WalletMigrationMessage.Start,
        sessionManager: SecureSessionManaging,
        eventCenter: EventCenterProtocol,
        logger: LoggerProtocol
    ) {
        self.sessionManager = sessionManager
        self.eventCenter = eventCenter
        originScheme = startMessage.originScheme
        self.logger = logger
    }
}

private extension WalletMigrateAcceptInteractor {
    func initiateSession() {
        presenter?.didRequestMigration(from: originScheme)
    }
    
    func acceptSession() {
        do {
            let publicKey = try sessionManager.startSession()
            
            // TODO: send public key to destination
        } catch {
            logger.error("Can't start session")
        }
    }
    
    func completeSession(with model: WalletMigrationMessage.Complete) {
        do {
            let decryptor = try sessionManager.deriveCryptor(peerPubKey: model.originPublicKey)
            
            let entropy = try decryptor.decrypt(model.encryptedData)
            
            // TODO: import entropy here
            
            presenter?.didCompleteMigration()
        } catch {
            logger.error("Can't complete wallet import \(error)")
        }
    }
    
    func handle(message: WalletMigrationMessage) {
        switch message {
        case let .start(model):
            originScheme = model.originScheme
            
            initiateSession()
        case let .complete(model):
            completeSession(with: model)
        case .accepted:
            logger.debug("Skipping accept event as we act as destination")
        }
    }
}

extension WalletMigrateAcceptInteractor: WalletMigrateAcceptInteractorInputProtocol {
    func setup() {
        initiateSession()
    }
    
    func accept() {
        acceptSession()
    }
}

extension WalletMigrateAcceptInteractor: EventVisitorProtocol {
    func processWalletMigration(event: WalletMigrationEvent) {
        handle(message: event.message)
    }
}
