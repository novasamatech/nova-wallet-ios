import XCTest
@testable import novawallet

final class WalletMigrationServiceTests: XCTestCase {
    let originScheme = "polkadotapp"
    let destinationScheme = "novawallet"
    
    func testCanStorePendingMessageIfNoDelegate() throws {
        // given
        
        let navigator = MockWalletMigrationLinkNavigator()
        
        let originChannel = WalletMigrationOrigin(
            destinationAppLinkURL: ApplicationConfig.shared.externalUniversalLinkURL,
            destinationScheme: ApplicationConfig.shared.deepLinkScheme,
            navigator: navigator
        )
        
        let expectedMessageContent = WalletMigrationMessage.Start(originScheme: originScheme)
        
        let destService = WalletMigrationService(localDeepLinkScheme: destinationScheme, logger: Logger.shared)
        
        // when
        
        try originChannel.start(with: expectedMessageContent)
        
        guard let url = navigator.lastOpenedLink else {
            XCTFail("No message")
            return
        }
        
        
        XCTAssert(destService.handle(url: url))
        
        // then
        
        XCTAssertEqual(destService.consumePendingMessage(), .start(expectedMessageContent))
        
        XCTAssertNil(destService.consumePendingMessage())
    }
    
    func testCanNotifyDelegateWhenMessageArrives() throws {
        // given
        
        let navigator = MockWalletMigrationLinkNavigator()
        
        let originChannel = WalletMigrationOrigin(
            destinationAppLinkURL: ApplicationConfig.shared.externalUniversalLinkURL,
            destinationScheme: ApplicationConfig.shared.deepLinkScheme,
            navigator: navigator
        )
        
        let expectedMessageContent = WalletMigrationMessage.Start(originScheme: originScheme)
        
        let destService = WalletMigrationService(localDeepLinkScheme: destinationScheme, logger: Logger.shared)
        let delegate = MockWalletMigrationDelegate()
        destService.delegate = delegate
        
        // when
        
        try originChannel.start(with: expectedMessageContent)
        
        guard let url = navigator.lastOpenedLink else {
            XCTFail("No message")
            return
        }
        
        XCTAssert(destService.handle(url: url))
        
        // then
        
        XCTAssertEqual(delegate.lastMessage, .start(expectedMessageContent))
        
        XCTAssertNil(destService.consumePendingMessage())
    }
}
