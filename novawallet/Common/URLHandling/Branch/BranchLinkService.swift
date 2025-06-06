import Foundation
import BranchSDK

protocol BranchLinkServiceProtocol {
    var isActive: Bool { get }

    func canHandle(url: URL) -> Bool
    func setup()
    func handle(url: URL)
}

final class BranchLinkService {
    private(set) var isActive = false

    let logger: LoggerProtocol
    let deepLinkHandler: URLHandlingServiceProtocol
    let deepLinkFactory: BranchDeepLinkFactoryProtocol

    let externalDeepLinkHost: String = "open"
    let deepLinkScheme: String
    let appLinkURL: URL

    init(
        deepLinkHandler: URLHandlingServiceProtocol,
        deepLinkFactory: BranchDeepLinkFactoryProtocol,
        appLinkURL: URL,
        deepLinkScheme: String,
        logger: LoggerProtocol
    ) {
        self.deepLinkHandler = deepLinkHandler
        self.deepLinkFactory = deepLinkFactory
        self.appLinkURL = appLinkURL
        self.deepLinkScheme = deepLinkScheme
        self.logger = logger
    }
}

private extension BranchLinkService {
    func setupSdk() {
        #if DEBUG
            Branch.enableLogging()
        #endif

        Branch.getInstance().setConsumerProtectionAttributionLevel(.reduced)
        
        Branch.getInstance().initSession(
            launchOptions: [:]
        ) { [weak self] (params: ExternalUniversalLinkParams?, _: Error?) in
            // Branch sdk delivers callback in the main queue

            guard let self else {
                return
            }

            guard
                let branchParams = params,
                let clickedBranchLink = branchParams[BranchParamKey.clickedBranchLink] as? NSNumber,
                clickedBranchLink.boolValue
            else {
                logger.debug("No branch link to handle")
                return
            }

            logger.debug("Handling branch link")

            handleDeepLinkByParams(branchParams)
        }
    }

    func handleDeepLinkByURL(_ url: URL) {
        let handled = Branch.getInstance().handleDeepLink(url)

        if handled {
            logger.debug("Branch link was handled")
        } else {
            logger.warning("Not branch link")
        }
    }

    func handleDeepLinkByParams(_ params: ExternalUniversalLinkParams) {
        guard let url = deepLinkFactory.createDeepLink(from: params) else {
            return
        }

        if deepLinkHandler.handle(url: url) {
            logger.debug("Deep link handled")
        } else {
            logger.warning("No deep link handler found")
        }
    }
}

extension BranchLinkService: BranchLinkServiceProtocol {
    func canHandle(url: URL) -> Bool {
        if url.scheme == deepLinkScheme {
            return url.host(percentEncoded: false) == externalDeepLinkHost
        } else {
            return url.isSameUniversalLinkDomain(appLinkURL)
        }
    }

    func setup() {
        guard !isActive else {
            logger.warning("Service already setup")
            return
        }

        isActive = true

        setupSdk()
    }

    func handle(url: URL) {
        guard isActive else {
            logger.warning("Service must be setup first")
            return
        }

        handleDeepLinkByURL(url)
    }
}
