import XCTest
@testable import novawallet
import UIKit.UIColor
import SubstrateSdk

class WalletRampProvidersTests: XCTestCase {
    let address = "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu"

    func testPurchaseProviders() throws {
        do {
            try performTransakRampTest(rampActionType: .onRamp)
            try performTransakRampTest(rampActionType: .offRamp)
            try performMercuryoRampTest(rampActionType: .onRamp)
            try performMercuryoRampTest(rampActionType: .offRamp)
        }
        catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func performTransakRampTest(rampActionType: RampActionType) throws {
        // given
        let providers = JSON.dictionaryValue(["transak": JSON.dictionaryValue([:])])
        
        let asset = ChainModelGenerator.generateAssetWithId(
            0,
            symbol: "DOT",
            buyProviders: providers,
            sellProviders: providers
        )
        
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        
        let accountId = try address.toAccountId()

        let apiKey = TransakProvider.pubToken
        let host = TransakProvider.baseUrlString
        let network = chain.name.lowercased()
        
        let expectedURL = switch rampActionType {
        case .offRamp:
            "\(host)?apiKey=\(apiKey)&network=\(network)&cryptoCurrencyCode=\(asset.symbol)&productsAvailed=SELL"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .onRamp:
            "\(host)?apiKey=\(apiKey)&network=\(network)&cryptoCurrencyCode=\(asset.symbol)&walletAddress=\(address)&disableWalletAddressForm=true&productsAvailed=BUY"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }
        
        let provider = switch rampActionType {
        case .offRamp:
            TransakProvider()
        case .onRamp:
            TransakProvider()
        }
        
        let operationQueue = OperationQueue()
        
        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildRampActions(for: chainAsset, accountId: accountId)
            .filter { $0.type == rampActionType }
        
        let urlWrapper = actions[0].urlFactory.createURLWrapper()
        
        operationQueue.addOperations(urlWrapper.allOperations, waitUntilFinished: true)
        
        do {
            let url = try urlWrapper.targetOperation.extractNoCancellableResultData()
            XCTAssertEqual(url.absoluteString, expectedURL)
            expectation.fulfill()

            // then
            wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
        } catch {
            XCTFail("Can't build ramp provider URL: \(error)")
        }
    }
    
    func performMercuryoRampTest(rampActionType: RampActionType) throws {
        // given
        let providers = JSON.dictionaryValue(["mercuryo": JSON.dictionaryValue([:])])
        
        let asset = ChainModelGenerator.generateAssetWithId(
            0,
            symbol: "DOT",
            buyProviders: providers,
            sellProviders: providers
        )
        
        let chain = ChainModelGenerator.generateChain(assets: [asset], addressPrefix: 0)
        let chainAsset = ChainAsset(chain: chain, asset: asset)

        let accountId = try address.toAccountId()
        let redirectUrl = ApplicationConfig.shared.purchaseRedirect
        
        let providerConfig = MercuryoProvider.Configuration.debug
        let host = providerConfig.baseUrl
        let widgetId = providerConfig.widgetId
        let signature = "9435d34696f6a8cc508b8cb79b871fd24f3acf033e3ca13af147a5b65cdfcc6ab249fc0ee29ad6a00d09d315cb9bd674a353750e4c77443788637b91128c1d23"

        // swiftlint:disable next long_string
        let expectedURL = switch rampActionType {
        case .offRamp:
            "\(host)?currency=\(asset.symbol)&type=sell&address=\(address)&widget_id=\(widgetId)&signature=\(signature)&hide_refund_address=true&refund_address=\(address)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .onRamp:
            "\(host)?currency=\(asset.symbol)&type=buy&address=\(address)&widget_id=\(widgetId)&signature=\(signature)&return_url=\(redirectUrl)"
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        }

        let provider = switch rampActionType {
        case .offRamp:
            MercuryoProvider()
        case .onRamp:
            MercuryoProvider().with(callbackUrl: redirectUrl)
        }

        // when
        let expectation = XCTestExpectation()

        let actions = provider.buildRampActions(for: chainAsset, accountId: accountId)
            .filter { $0.type == rampActionType }
        
        XCTAssertEqual(actions[0].url.absoluteString, expectedURL)
        expectation.fulfill()

        // then
        wait(for: [expectation], timeout: Constants.defaultExpectationDuration)
    }
}
