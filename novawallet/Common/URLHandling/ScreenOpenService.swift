import Foundation
import SubstrateSdk

protocol ScreenOpenDelegate: AnyObject {
    func didAskScreenOpen(_ screen: UrlHandlingScreen)
}

enum UrlHandlingScreen {
    case staking
    case gov(Referenda.ReferendumIndex)
    case dApp(DAppNavigation)
    case card(PayCardNavigation?)
    case assetHubMigration(AHMNavigation)
    case giftClaim(GiftClaimNavigation)
    case error(UrlHandlingScreenError)
}

extension UrlHandlingScreen {
    init?(pendingLink: URLHandlingPendingLink) {
        switch pendingLink {
        case .staking:
            self = .staking
        case let .governance(referendumIndex):
            self = .gov(referendumIndex)
        case let .dApp(url):
            self = .dApp(.init(url: url))
        case let .card(provider):
            self = .card(.init(rawValue: provider ?? ""))
        case let .assetHubMigration(config):
            self = .assetHubMigration(.init(config: config))
        case let .giftClaim(payload, amount):
            self = .giftClaim(.init(claimableGiftPayload: payload, totalAmount: amount))
        }
    }

    var pendingLink: URLHandlingPendingLink? {
        switch self {
        case .staking:
            .staking
        case let .gov(referendumIndex):
            .governance(referendumIndex)
        case let .dApp(navigation):
            .dApp(navigation.url)
        case let .card(navigation):
            .card(navigation?.rawValue)
        case let .assetHubMigration(navigation):
            .assetHubMigration(config: navigation.config)
        case let .giftClaim(navigation):
            .giftClaim(
                giftPayload: navigation.claimableGiftPayload,
                amount: navigation.totalAmount
            )
        case .error:
            nil
        }
    }
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
    let pendingLinkStore: URLHandlingStoreProtocol
    let validators: [URLActivityValidator]

    init(
        parsingFactory: OpenScreenUrlParsingServiceFactoryProtocol,
        pendingLinkStore: URLHandlingStoreProtocol,
        logger: LoggerProtocol,
        validators: [URLActivityValidator]
    ) {
        self.parsingFactory = parsingFactory
        self.pendingLinkStore = pendingLinkStore
        self.logger = logger
        self.validators = validators

        restorePendingScreen()
    }
}

extension ScreenOpenService {
    struct ActivityValidator: URLActivityValidator {
        func validate(_ url: URL) -> Bool {
            let deeplinkHost = ApplicationConfig.shared.deepLinkHost
            let applinkHost = ApplicationConfig.shared.internalUniversalLinkURL.host

            guard url.host == deeplinkHost || url.host == applinkHost else {
                return false
            }

            return true
        }
    }
}

private extension ScreenOpenService {
    func restorePendingScreen() {
        if let pendingLink = pendingLinkStore.getPendingLink() {
            pendingScreen = UrlHandlingScreen(pendingLink: pendingLink)
        }
    }

    func save(preparedScreen: UrlHandlingScreen) {
        do {
            if let pendingLink = preparedScreen.pendingLink {
                try pendingLinkStore.save(pendingLink: pendingLink)
            } else {
                pendingLinkStore.clearPendingLink()
            }
        } catch {
            logger.error("Screen pending deep link save failed")
        }
    }

    func markPendingScreenConsumed() {
        pendingScreen = nil
        pendingLinkStore.clearPendingLink()
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
                self?.save(preparedScreen: preparedScreen)
                screen = preparedScreen
            case let .failure(error):
                self?.logger.error("error occurs: \(error) while parse url: \(url.absoluteString)")
                self?.pendingLinkStore.clearPendingLink()
                screen = .error(.deeplink(error))
            }

            DispatchQueue.main.async {
                if let delegate = self?.delegate {
                    self?.markPendingScreenConsumed()
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

        markPendingScreenConsumed()

        return screen
    }
}
