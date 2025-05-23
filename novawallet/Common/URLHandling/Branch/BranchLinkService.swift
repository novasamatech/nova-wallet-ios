import Foundation
import BranchSDK

final class BranchLinkService {
    private(set) var isActive = false

    let logger: LoggerProtocol
    let deepLinkHandler: URLHandlingServiceProtocol
    let deepLinkFactory: BranchDeepLinkFactoryProtocol

    init(
        deepLinkHandler: URLHandlingServiceProtocol,
        deepLinkFactory: BranchDeepLinkFactoryProtocol,
        logger: LoggerProtocol
    ) {
        self.deepLinkHandler = deepLinkHandler
        self.deepLinkFactory = deepLinkFactory
        self.logger = logger
    }
}

private extension BranchLinkService {
    func setupSdk(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        #if DEBUG
            Branch.enableLogging()
        #endif

        Branch.getInstance().initSession(
            launchOptions: launchOptions
        ) { [weak self] (params: ExternalUniversalLink.Params?, _: Error?) in
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

            handleDeepLink(params: branchParams)
        }
    }

    func handleDeepLink(params: ExternalUniversalLink.Params) {
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

extension BranchLinkService {
    func setup(with launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard !isActive else {
            logger.warning("Service already setup")
            return
        }

        isActive = true

        setupSdk(with: launchOptions)
    }
}
