import XCTest
@testable import novawallet
import UIKit.UIColor
import SubstrateSdk

class WalletPurchaseProvidersTests: XCTestCase {
    let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

    func testPurchaseProviders() throws {
        do {
            try performRampTest()
            try performMoonPayTest()
            try performTransakTest()
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func performRampTest() throws {
        // given
        let buyProviders = JSON.dictionaryValue(["ramp": JSON.dictionaryValue([:])])
        let asset = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", buyProviders: buyProviders)
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()

        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let apiKey = RampProvider.pubToken
        let host = RampProvider.baseUrlString
        let redirectUrl = config.purchaseRedirect
        let appName = config.purchaseAppName
        let logoUrl = config.logoURL

        // swiftlint:disable next long_string
        let expectedUrl = "\(host)?swapAsset=\(asset.symbol)&userAddress=\(address)&hostApiKey=\(apiKey)&variant=hosted-mobile&finalUrl=\(redirectUrl)&hostAppName=\(appName)&hostLogoUrl=\(logoUrl)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        let provider = RampProvider()
            .with(appName: config.purchaseAppName)
            .with(logoUrl: config.logoURL)
            .with(callbackUrl: config.purchaseRedirect)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseActions(for: chainAsset, accountId: accountId)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }

    func performMoonPayTest() throws {
        // given
        let buyProviders = JSON.dictionaryValue(["moonpay": JSON.dictionaryValue([:])])
        let asset = ChainModelGenerator.generateAssetWithId(0, symbol: "DOT", buyProviders: buyProviders)
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()

        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let apiKey = "pk_test_DMRuyL6Nf1qc9OzjPBmCFBeCGkFwiZs0"
        let secretKey = "1"
        let redirectUrl = config.purchaseRedirect
        let colorCode = R.color.colorAccent()!.hexRGB

        // swiftlint:disable next long_string
        let query = "apiKey=\(apiKey)&currencyCode=\(asset.symbol)&walletAddress=\(address)&showWalletAddressForm=true&colorCode=\(colorCode)&redirectURL=\(redirectUrl)"
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""

        let expectedUrl = "https://buy.moonpay.com/?\(query)&signature=oXX0CUdPjd5XrjoogHBbDAucVipQuB7DgtsyqwutFTQ%3D"

        let secretKeyData = Data(secretKey.utf8)

        let provider = MoonpayProviderFactory().createProvider(with: secretKeyData, apiKey: apiKey)
            .with(colorCode: R.color.colorAccent()!.hexRGB)
            .with(callbackUrl: config.purchaseRedirect)

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildPurchaseActions(for: chainAsset, accountId: accountId)
        XCTAssertEqual(actions[0].url.absoluteString, expectedUrl)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
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
}
