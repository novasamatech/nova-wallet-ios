import Foundation

protocol PushScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: PushHandlingScreen)
}

enum PushHandlingScreen {
    case gov(Referenda.ReferendumIndex)
    case historyDetails(ChainAssetId)
    case error(Error)
}

protocol PushScreenOpenServiceProtocol: PushHandlingServiceProtocol {
    var delegate: PushScreenOpenDelegate? { get set }

    func consumePendingScreenOpen() -> PushHandlingScreen?
}

final class PushScreenOpenService {
    weak var delegate: PushScreenOpenDelegate?
    private var pendingScreen: PushHandlingScreen?
    private var processingHandler: OpenScreenPushServiceProtocol?
    private lazy var decoder = JSONDecoder()
    private let delegateQueue: DispatchQueue

    let logger: LoggerProtocol
    let handlingFactory: OpenScreenPushHandlingServiceFactory

    init(
        handlingFactory: OpenScreenPushHandlingServiceFactory,
        delegateQueue: DispatchQueue = .main,
        logger: LoggerProtocol
    ) {
        self.handlingFactory = handlingFactory
        self.delegateQueue = delegateQueue
        self.logger = logger
    }
}

extension PushScreenOpenService: PushScreenOpenServiceProtocol {
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

            let screen: PushHandlingScreen
            switch result {
            case let .success(preparedScreen):
                screen = preparedScreen
                completion(true)
            case let .failure(error):
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

    func consumePendingScreenOpen() -> PushHandlingScreen? {
        let screen = pendingScreen

        pendingScreen = nil

        return screen
    }
}
