import XCTest
@testable import novawallet
import Keystore_iOS

final class BranchInitTests: XCTestCase {
    func testBranchInitsOnFirstLaunch() {
        // given

        let settingsManager = InMemorySettingsManager()

        let branchService = MockBranchService()
        let urlHandlingFacade = URLHandlingServiceFacade(
            urlHandlingService: URLHandlingService(children: []),
            branchLinkService: branchService,
            settingsManager: settingsManager,
            appConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        // when

        urlHandlingFacade.configure()

        // then

        XCTAssertTrue(branchService.isActive)
        XCTAssertNil(branchService.lastHandledURL)
    }

    func testBranchNotInitOnSubsequentLaunch() {
        // given

        let settingsManager = InMemorySettingsManager()

        let branchService = MockBranchService()
        let urlHandlingFacade = URLHandlingServiceFacade(
            urlHandlingService: URLHandlingService(children: []),
            branchLinkService: branchService,
            settingsManager: settingsManager,
            appConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        // when

        settingsManager.isAppFirstLaunch = false

        urlHandlingFacade.configure()

        // then

        XCTAssertFalse(branchService.isActive)
        XCTAssertNil(branchService.lastHandledURL)
    }

    func testBranchInitsOnLinkHandle() {
        // given

        let settingsManager = InMemorySettingsManager()

        let branchService = MockBranchService()
        let urlHandlingFacade = URLHandlingServiceFacade(
            urlHandlingService: URLHandlingService(children: []),
            branchLinkService: branchService,
            settingsManager: settingsManager,
            appConfig: ApplicationConfig.shared,
            logger: Logger.shared
        )

        let link = ExternalLinkFactory(
            baseUrl: ApplicationConfig.shared.externalUniversalLinkURL
        ).createUrlForStaking()!

        // when

        urlHandlingFacade.configure()

        // then

        XCTAssertTrue(branchService.isActive)

        // when

        let isHandled = urlHandlingFacade.handle(url: link)

        // then

        XCTAssert(isHandled)
        XCTAssertEqual(link, branchService.lastHandledURL)
    }
}
