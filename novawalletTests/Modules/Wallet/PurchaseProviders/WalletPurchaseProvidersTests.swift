import XCTest
@testable import novawallet
import UIKit.UIColor
import SubstrateSdk

class WalletPurchaseProvidersTests: XCTestCase {
    let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

    func testPurchaseProviders() throws {
        do {
            try performTransakTest()
            try performMercuryoTest()
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performTransakTest() throws {
        // given
        let buyProviders = JSON.dictionaryValue(["transak": JSON.dictionaryValue([:])])
        let asset = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", buyProviders: buyProviders)
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()

        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let apiKey = TransakProvider.pubToken
        let host = TransakProvider.baseUrlString
        let network = chain.name.lowercased()

        // swiftlint:disable next long_string
        let expectedUrl = "\(host)?apiKey=\(apiKey)&network=\(network)&cryptoCurrencyCode=\(asset.symbol)&walletAddress=\(address)&disableWalletAddressForm=true"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        let provider = TransakProvider().with(callbackUrl: config.purchaseRedirect)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseActions(for: chainAsset, accountId: accountId)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
    
    func performMercuryoTest() throws {
        // given
        let buyProviders = JSON.dictionaryValue(["mercuryo": JSON.dictionaryValue([:])])
        let asset = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", buyProviders: buyProviders)
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()
        let redirectUrl = ApplicationConfig.shared.purchaseRedirect
        
        let providerConfig = MercuryoProvider.Configuration.debug
        let host = providerConfig.baseUrl
        let widgetId = providerConfig.widgetId
        let signature = "9435d34696f6a8cc508b8cb79b871fd24f3acf033e3ca13af147a5b65cdfcc6ab249fc0ee29ad6a00d09d315cb9bd674a353750e4c77443788637b91128c1d23"

        // swiftlint:disable next long_string
        let expectedUrl = "\(host)?currency=\(asset.symbol)&type=buy&address=\(address)&return_url=\(redirectUrl)&widget_id=\(widgetId)&signature=\(signature)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        let provider = MercuryoProvider().with(callbackUrl: redirectUrl)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseActions(for: chainAsset, accountId: accountId)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
