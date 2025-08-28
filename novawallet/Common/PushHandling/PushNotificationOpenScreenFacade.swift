import Foundation
import Foundation_iOS

protocol PushNotificationOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: PushNotification.OpenScreen)
}

extension PushNotification {
    enum OpenScreen {
        case gov(Referenda.ReferendumIndex)
        case historyDetails(ChainAsset)
        case multisigOperationDetails(Multisig.PendingOperation.Key)
        case multisigOperationEnded(MultisigEndedMessageModel)
        case error(Error)
    }
}

protocol PushNotificationMessageHandlingProtocol: AnyObject {
    func handle(
        message: NotificationMessage,
        completion: @escaping (Result<PushNotification.OpenScreen, Error>) -> Void
    )
    func cancel()
}

protocol PushNotificationOpenScreenFacadeProtocol: PushNotificationHandlingServiceProtocol {
    var delegate: PushNotificationOpenDelegate? { get set }

    func consumePendingScreenOpen() -> PushNotification.OpenScreen?
}

final class PushNotificationOpenScreenFacade {
    weak var delegate: PushNotificationOpenDelegate?
    private var pendingScreen: PushNotification.OpenScreen?
    private var processingHandler: PushNotificationMessageHandlingProtocol?
    private lazy var decoder = JSONDecoder()
    private let delegateQueue: DispatchQueue

    let logger: LoggerProtocol
    let handlingFactory: PushNotificationsHandlerFactory

    init(
        handlingFactory: PushNotificationsHandlerFactory,
        delegateQueue: DispatchQueue = .main,
        logger: LoggerProtocol
    ) {
        self.handlingFactory = handlingFactory
        self.delegateQueue = delegateQueue
        self.logger = logger
    }
}

extension PushNotificationOpenScreenFacade: PushNotificationOpenScreenFacadeProtocol {
    func handle(userInfo: [AnyHashable: Any], completion: @escaping (Bool) -> Void) {
        guard let message = try? NotificationMessage(userInfo: userInfo, decoder: decoder) else {
            logger.warning("Can't parse message")
            completion(false)
            return
        }
        processingHandler?.cancel()

        guard let handler = handlingFactory.createHandler(message: message) else {
            completion(false)
            return
        }
        processingHandler = handler

        handler.handle(message: message) { [weak self] result in
            guard let self = self, handler === self.processingHandler else {
                return
            }

            let screen: PushNotification.OpenScreen
            switch result {
            case let .success(preparedScreen):
                screen = preparedScreen
                completion(true)
            case .failure:
                completion(false)
                return
            }

            dispatchInQueueWhenPossible(self.delegateQueue) {
                if let delegate = self.delegate {
                    self.pendingScreen = nil
                    delegate.didAskScreenOpen(screen)
                } else {
                    self.pendingScreen = screen
                }
            }
        }
    }

    func consumePendingScreenOpen() -> PushNotification.OpenScreen? {
        let screen = pendingScreen

        pendingScreen = nil

        return screen
    }
}
