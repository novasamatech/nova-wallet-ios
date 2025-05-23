import Foundation
import Keystore_iOS

protocol URLHandlingServiceFacadeProtocol {
    func configure(launchOptions: AppLaunchOptions?)
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

    let branchLinkService: BranchLinkService
    let settingsManager: SettingsManagerProtocol
    let urlHandlingService: URLServiceHandlingFinding
    let appConfig: ApplicationConfigProtocol
    let logger: LoggerProtocol

    private var delayedLaunchOptions: AppLaunchOptions?

    static func setup(with urlHandlingService: URLServiceHandlingFinding) {
        shared = URLHandlingServiceFacade(
            urlHandlingService: urlHandlingService,
            settingsManager: SettingsManager.shared,
            appConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )
    }

    init(
        urlHandlingService: URLServiceHandlingFinding,
        settingsManager: SettingsManagerProtocol,
        appConfig: ApplicationConfigProtocol,
        logger: LoggerProtocol
    ) {
        self.urlHandlingService = urlHandlingService
        self.settingsManager = settingsManager
        self.appConfig = appConfig
        self.logger = logger

        branchLinkService = BranchLinkService(
            deepLinkHandler: urlHandlingService,
            deepLinkFactory: BranchDeepLinkFactory(config: appConfig),
            logger: logger
        )
    }
}

private extension URLHandlingServiceFacade {
    func setupBranchIfNeeded(for launchOptions: AppLaunchOptions?) {
        guard !branchLinkService.isActive else {
            return
        }

        logger.debug("Setup branch service")

        branchLinkService.setup(with: launchOptions)
    }
}

extension URLHandlingServiceFacade: URLHandlingServiceFacadeProtocol {
    func configure(launchOptions: AppLaunchOptions?) {
        if settingsManager.isAppFirstLaunch {
            setupBranchIfNeeded(for: launchOptions)
        } else {
            logger.debug("No need to init branch for now")
            delayedLaunchOptions = launchOptions
        }
    }

    @discardableResult
    func handle(url: URL) -> Bool {
        if appConfig.externalUniversalLinkURL.isSameUniversalLinkDomain(url) {
            setupBranchIfNeeded(for: delayedLaunchOptions)
            return true
        } else {
            if urlHandlingService.handle(url: url) {
                logger.debug("Link has been handled")
                return true
            } else {
                logger.warning("No link handler found")
                return false
            }
        }
    }

    func findInternalService<T>() -> T? {
        urlHandlingService.findService()
    }
}
