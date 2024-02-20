import Foundation
import SubstrateSdk

protocol ScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: UrlHandlingScreen)
}

enum UrlHandlingScreen {
    case staking
    case gov(Referenda.ReferendumIndex)
    case dApp(DApp)
    case error(UrlHandlingScreenError)
}

enum UrlHandlingScreenError {
    case deeplink(OpenScreenUrlParsingError)
    case content(ErrorContentConvertible & Error)

    func content(for locale: Locale?) -> ErrorContent? {
        let locale = locale ?? .current
        switch self {
        case let .deeplink(deeplinkParseError):
            return deeplinkParseError.message(locale: locale).map {
                ErrorContent(title: "", message: $0)
            }
        case let .content(contentError):
            return contentError.toErrorContent(for: locale)
        }
    }
}

protocol ScreenOpenServiceProtocol: URLHandlingServiceProtocol {
    var delegate: ScreenOpenDelegate? { get set }

    func consumePendingScreenOpen() -> UrlHandlingScreen?
}

final class ScreenOpenService {
    weak var delegate: ScreenOpenDelegate?

    private var pendingScreen: UrlHandlingScreen?
    private var processingHandler: OpenScreenUrlParsingServiceProtocol?

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
        guard url.host == "nova" else {
            return false
        }

        let pathComponents = url.pathComponents
        guard pathComponents.count == 3 else {
            return false
        }

        guard UrlHandlingAction(rawValue: pathComponents[1]) == .open else {
            return false
        }

        processingHandler?.cancel()

        guard let handler = parsingFactory.createUrlHandler(screen: pathComponents[2]) else {
            logger.warning("unsupported screen: \(pathComponents[2])")
            return false
        }
        processingHandler = handler

        handler.parse(url: url) { [weak self] result in
            guard handler === self?.processingHandler else {
                return
            }

            let screen: UrlHandlingScreen
            switch result {
            case let .success(preparedScreen):
                screen = preparedScreen
            case let .failure(error):
                self?.logger.error("error occurs: \(error) while parse url: \(url.absoluteString)")
                screen = .error(.deeplink(error))
            }

            DispatchQueue.main.async {
                if let delegate = self?.delegate {
                    self?.pendingScreen = nil
                    delegate.didAskScreenOpen(screen)
                } else {
                    self?.pendingScreen = screen
                }
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
