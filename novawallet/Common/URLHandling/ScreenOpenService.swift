import Foundation
import SubstrateSdk

protocol ScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: UrlHandlingScreen)
}

enum UrlHandlingScreen {
    case staking
    case gov(ReferendumsInitState)
    case dApp(DApp)
    case error(DeeplinkParseError)
}

struct ReferendumsInitState {
    let chainId: ChainModel.Id
    let referendumIndex: UInt
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
    let parsingFactory: OpenScreenUrlParsingServiceFactoryProtocol

    init(
        parsingFactory: OpenScreenUrlParsingServiceFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.parsingFactory = parsingFactory
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
        guard let handler = parsingFactory.createUrlHandler(screen: pathComponents[2]) else {
            logger.warning("unsupported screen: \(pathComponents[2])")
            return false
        }
        let parsingResult = handler.parse(url: url)

        switch parsingResult {
        case let .success(preparedScreen):
            screen = preparedScreen
        case let .failure(error):
            logger.error("error occurs: \(error) while parse url: \(url.absoluteString)")
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
