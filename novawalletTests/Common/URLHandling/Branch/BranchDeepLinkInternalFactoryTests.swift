import XCTest
@testable import novawallet

final class BranchDeepLinkInternalFactoryTests: XCTestCase {

    func testDAppPathConverted() {
        let path = "nova/open/dapp?url=https://app.hydration.net/NOVA"
        
        let config = ApplicationConfig.shared
        let converter = BranchDeepLinkInternalFactory(scheme: config.deepLinkScheme)
        
        let converted = converter.createInternalLink(
            from: [
                BranchParamKey.deepLinkPath: path
            ]
        )
        let expected = URL(string: "\(config.deepLinkScheme)://" + path)!
        
        XCTAssertEqual(converted, expected)
    }
}
