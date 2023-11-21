import Foundation
import SubstrateSdk

protocol ScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: UrlHandlingScreen)
}

enum UrlHandlingScreen {
    case staking
    case gov(ReferendumsInitState)
    case error(DeeplinkParseError)
}

struct ReferendumsInitState {
    let chainId: ChainModel.Id
    let referendumId: UInt
    let governance: GovernanceType
}

protocol ScreenOpenServiceProtocol: URLHandlingServiceProtocol {
    var delegate: ScreenOpenDelegate? { get set }

    func consumePendingScreenOpen() -> UrlHandlingScreen?
}

final class ScreenOpenService {
    weak var delegate: ScreenOpenDelegate?

    private var pendingScreen: UrlHandlingScreen?

    let logger: LoggerProtocol
    let factory: DeeplinkOpenScreenParsingServiceFactoryProtocol

    init(
        factory: DeeplinkOpenScreenParsingServiceFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.factory = factory
        self.logger = logger
    }
}

extension ScreenOpenService: ScreenOpenServiceProtocol {
    func handle(url: URL) -> Bool {
        // we are expecting nova/open/{screen}
        let pathComponents = url.pathComponents
        guard pathComponents.count == 3 else {
            return false
        }

        guard UrlHandlingAction(rawValue: pathComponents[1]) == .open else {
            return false
        }

        let screen: UrlHandlingScreen
        guard let handler = factory.createUrlHandler(screen: pathComponents[2]) else {
            logger.warning("unsupported screen: \(pathComponents[2])")
            return false
        }
        let parsingResult = handler.parse(url: url)

        switch parsingResult {
        case let .success(parsedScreen):
            screen = parsedScreen
        case let .failure(error):
            logger.warning("error occurs while parse url: \(error)")
            screen = .error(error)
        }

        DispatchQueue.main.async { [weak self] in
            if let delegate = self?.delegate {
                self?.pendingScreen = nil
                delegate.didAskScreenOpen(screen)
            } else {
                self?.pendingScreen = screen
            }
        }

        return true
    }

    func consumePendingScreenOpen() -> UrlHandlingScreen? {
        let screen = pendingScreen

        pendingScreen = nil

        return screen
    }
}
