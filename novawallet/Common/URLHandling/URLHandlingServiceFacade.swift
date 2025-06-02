import Foundation
import Keystore_iOS

protocol URLHandlingServiceFacadeProtocol {
    func configure()
    func handle(url: URL) -> Bool
    func findInternalService<T>() -> T?
}

/*
 *  The service handles routing logic depending on the handling url.
 *  It can deferrentiate between branch links and nova universal links.
 *  The service makes an assumption that actual url handling service is proper configured
 *  before `handle(url: URL)` method is called
 */
final class URLHandlingServiceFacade {
    private(set) static var shared: URLHandlingServiceFacade!

    let branchLinkService: BranchLinkServiceProtocol
    let settingsManager: SettingsManagerProtocol
    let urlHandlingService: URLServiceHandlingFinding
    let appConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol

    private var delayedLaunchOptions: AppLaunchOptions?

    static func setup(with urlHandlingService: URLServiceHandlingFinding) {
        let appConfig = ApplicationConfig.shared

        let branchLinkService = BranchLinkService(
            deepLinkHandler: urlHandlingService,
            deepLinkFactory: BranchDeepLinkFactory(config: appConfig),
            appLinkURL: appConfig.externalUniversalLinkURL,
            deepLinkScheme: appConfig.deepLinkScheme,
            logger: Logger.shared
        )

        setup(with: urlHandlingService, branchService: branchLinkService)
    }

    static func setup(
        with urlHandlingService: URLServiceHandlingFinding,
        branchService: BranchLinkServiceProtocol
    ) {
        shared = URLHandlingServiceFacade(
            urlHandlingService: urlHandlingService,
            branchLinkService: branchService,
            settingsManager: SettingsManager.shared,
            appConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )
    }

    init(
        urlHandlingService: URLServiceHandlingFinding,
        branchLinkService: BranchLinkServiceProtocol,
        settingsManager: SettingsManagerProtocol,
        appConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        self.urlHandlingService = urlHandlingService
        self.branchLinkService = branchLinkService
        self.settingsManager = settingsManager
        self.appConfig = appConfig
        self.logger = logger
    }
}

private extension URLHandlingServiceFacade {
    func setupBranchIfNeeded() {
        guard !branchLinkService.isActive else {
            return
        }

        logger.debug("Setup branch service")

        branchLinkService.setup()
    }

    func handleBranch(url: URL) -> Bool {
        setupBranchIfNeeded()
        branchLinkService.handle(url: url)
        return true
    }

    func handleInternal(url: URL) -> Bool {
        if urlHandlingService.handle(url: url) {
            logger.debug("Link has been handled")
            return true
        } else {
            logger.warning("No link handler found")
            return false
        }
    }
}

extension URLHandlingServiceFacade: URLHandlingServiceFacadeProtocol {
    func configure() {
        if settingsManager.isAppFirstLaunch {
            setupBranchIfNeeded()
        } else {
            logger.debug("No need to init branch for now")
        }
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        if branchLinkService.canHandle(url: url) {
            handleBranch(url: url)
        } else {
            handleInternal(url: url)
        }
    }

    func findInternalService<T>() -> T? {
        urlHandlingService.findService()
    }
}
