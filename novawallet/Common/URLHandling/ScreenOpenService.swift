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
    let validators: [URLActivityValidator]

    init(
        parsingFactory: OpenScreenUrlParsingServiceFactoryProtocol,
        logger: LoggerProtocol,
        validators: [URLActivityValidator]
    ) {
        self.parsingFactory = parsingFactory
        self.logger = logger
        self.validators = validators
    }
}

extension ScreenOpenService {
    struct ActivityValidator: URLActivityValidator {
        func validate(_ url: URL) -> Bool {
            let deeplinkHost = "nova"
            let applinkHost = ApplicationConfig.shared.novaWalletURL.host

            guard url.host == deeplinkHost || url.host == applinkHost else {
                return false
            }

            return true
        }
    }
}

extension ScreenOpenService: ScreenOpenServiceProtocol {
    func handle(url: URL) -> Bool {
        guard validators.allSatisfy({ $0.validate(url) }) else { return false }

        guard
            let action = UrlHandlingAction(from: url),
            case let .open(screen) = action
        else {
            return false
        }

        processingHandler?.cancel()

        guard let handler = parsingFactory.createUrlHandler(screen: screen) else {
            logger.warning("unsupported screen: \(screen)")
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
