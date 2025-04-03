import XCTest
@testable import novawallet
import SubstrateSdk

final class XcmUniCodingTests: XCTestCase {

    func testEncodeDecodeV2AccountId32() throws {
        try performEncodeDecodeTest(
            for: XcmUni.Versioned(
                entity: XcmUni.AccountId32(
                    network: .any,
                    accountId: Data.randomBytes(length: 32)!
                ),
                version: .V2
            )
        )
    }
    
    func testEncodeDecodeV5AccountId20() throws {
        try performEncodeDecodeTest(
            for: XcmUni.Versioned(
                entity: XcmUni.Junction.accountKey20(
                    XcmUni.AccountId20(
                        network: .any,
                        accountId: Data.randomBytes(length: 20)!
                    )
                ),
                version: .V5
            )
        )
    }
    
    func testEncodeDecodeV5AccountId20ByGenesis() throws {
        let networkId = "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3"
        
        try performEncodeDecodeTest(
            for: XcmUni.Versioned(
                entity: XcmUni.Junction.accountKey20(
                    XcmUni.AccountId20(
                        network: .other("ByGenesis", JSON.stringValue(networkId)),
                        accountId: Data.randomBytes(length: 20)!
                    )
                ),
                version: .V5
            )
        )
    }
    
    private func performEncodeDecodeTest<T: Equatable & XcmUniCodable>(
        for versionedEntity: XcmUni.Versioned<T>
    ) throws {
        let encoded = try JSONEncoder().encode(versionedEntity)
        let decoded = try JSONDecoder().decode(XcmUni.Versioned<T>.self, from: encoded)
        
        XCTAssertEqual(versionedEntity, decoded)
    }
}
