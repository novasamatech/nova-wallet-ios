import XCTest
@testable import novawallet

final class BranchToInternalConvertionTests: XCTestCase {
    var deepLinkURL: URL {
        ApplicationConfig.shared.deepLinkURL
    }
    
    func testStakingLinkConverstion() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "open",
                ExternalUniversalLinkKey.screen.rawValue: "staking",
            ],
            expectedPath: "/open/staking",
            expectedQueryItems: [:]
        )
    }
    
    func testOpenGovLinkConverstion() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "open",
                ExternalUniversalLinkKey.screen.rawValue: "gov",
                UniversalLink.GovScreen.QueryKey.chainid: KnowChainId.polkadot,
                UniversalLink.GovScreen.QueryKey.referendumIndex: "123",
                UniversalLink.GovScreen.QueryKey.governanceType: "0",
            ],
            expectedPath: "/open/gov",
            expectedQueryItems: [
                UniversalLink.GovScreen.QueryKey.chainid: KnowChainId.polkadot,
                UniversalLink.GovScreen.QueryKey.referendumIndex: "123",
                UniversalLink.GovScreen.QueryKey.governanceType: "0"
            ]
        )
    }
    
    func testDappLinkConverstion() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "open",
                ExternalUniversalLinkKey.screen.rawValue: "dapp",
                UniversalLink.DAppScreen.QueryKey.url: "https://hydration.io"
            ],
            expectedPath: "/open/dapp",
            expectedQueryItems: [
                UniversalLink.DAppScreen.QueryKey.url: "https://hydration.io"
            ]
        )
    }
    
    func testMnemonicLinkConverstion() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "create",
                ExternalUniversalLinkKey.screen.rawValue: "wallet",
                UniversalLink.WalletEntity.QueryKey.mnemonic: "0x00",
                UniversalLink.WalletEntity.QueryKey.type: "0",
                UniversalLink.WalletEntity.QueryKey.substrateDp: "//substrate",
                UniversalLink.WalletEntity.QueryKey.evmDp: "//evm"
            ],
            expectedPath: "/create/wallet",
            expectedQueryItems: [
                UniversalLink.WalletEntity.QueryKey.mnemonic: "0x00",
                UniversalLink.WalletEntity.QueryKey.type: "0",
                UniversalLink.WalletEntity.QueryKey.substrateDp: "//substrate",
                UniversalLink.WalletEntity.QueryKey.evmDp: "//evm"
            ]
        )
    }
    
    func testAHMLinkConverstion() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "open",
                ExternalUniversalLinkKey.screen.rawValue: "ahm",
                UniversalLink.AssetHubMigration.QueryKey.chainId: KnowChainId.polkadot
            ],
            expectedPath: "/open/ahm",
            expectedQueryItems: [
                UniversalLink.AssetHubMigration.QueryKey.chainId: KnowChainId.polkadot
            ]
        )
    }
    
    func testBranchParamsIgnored() {
        performTest(
            for: [
                ExternalUniversalLinkKey.action.rawValue: "open",
                ExternalUniversalLinkKey.screen.rawValue: "staking",
                BranchParamKey.clickedBranchLink: "https://branch.io"
            ],
            expectedPath: "/open/staking",
            expectedQueryItems: [:]
        )
    }
    
    private func performTest(
        for params: ExternalUniversalLinkParams,
        expectedPath: String,
        expectedQueryItems: [String: String]
    ) {
        guard let resultLink = BranchToDeepLinkConversionFactory(
                baseUrl: deepLinkURL
        ).createInternalLink(from: params) else {
            XCTFail("Can't create link")
            return
        }
        
        XCTAssert(resultLink.isSameUniversalLinkDomain(deepLinkURL))
        XCTAssertEqual(resultLink.path(percentEncoded: false), expectedPath)
        
        guard let components = URLComponents(url: resultLink, resolvingAgainstBaseURL: false) else {
            XCTFail("Can't create URLComponents")
            return
        }
        
        let actualQueryItems = (components.queryItems ?? []).reduce(into: [:]) { result, item in
            result[item.name] = item.value
        }
        
        XCTAssertEqual(actualQueryItems, expectedQueryItems)
    }
}
