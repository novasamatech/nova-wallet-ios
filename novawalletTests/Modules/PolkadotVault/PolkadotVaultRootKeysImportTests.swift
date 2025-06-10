import XCTest
@testable import novawallet
import SubstrateSdk

final class PolkadotVaultRootKeysImportTests: XCTestCase {

    func testMatchRootKeys() throws {
        let encodedData = try Data(hexString: "44408011464400b1dd88809b516102cef1cda69f3655072c2a5fd45ea1270d5422843610302164ccce2b5b037dd92156d9bed6e443ca721a5c16fe08c7b0cf562b5f20ab8f50ec11ec11ec11").dropFirst(2)
        
        let matcher = ParitySignerScanMatcher()
        
        let matchedFormat = matcher.match(code: .raw(Data(encodedData)))
        
        XCTAssertNotNil(matchedFormat)
    }

    func testEncodePublicKeys() throws {
        let substrate = ParitySignerWalletScan.RootPublicKey.sr25519(Data(repeating: 0, count: 32))
        let ethereum = ParitySignerWalletScan.RootPublicKey.ethereumEcdsa(Data(repeating: 0, count: 33))
        
        let encoder = ScaleEncoder()
        try [substrate, ethereum].encode(scaleEncoder: encoder)
        
        let data = encoder.encode()
        
        Logger.shared.info("Result: \(data.toHexString())")
    }
}
