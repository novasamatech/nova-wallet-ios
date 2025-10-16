import XCTest
@testable import novawallet

final class HydraPoolAccountTests: XCTestCase {
    func testXYKAccountGenerationBigs() throws {
        let assetIn: HydraDx.AssetId = 1_000_062
        let assetOut: HydraDx.AssetId = 1_000_034

        let accountId = try HydraXYK.deriveAccount(from: assetIn, asset2: assetOut)

        XCTAssertEqual(accountId.toHexString(), "adfda73f4498a170ba675acd9d413336ee8235a07c3007ea0282588a433bd447")
    }

    func testXYKAccountGenerationSmallBig() throws {
        let assetIn: HydraDx.AssetId = 5
        let assetOut: HydraDx.AssetId = 1_000_131

        let accountId = try HydraXYK.deriveAccount(from: assetIn, asset2: assetOut)

        XCTAssertEqual(accountId.toHexString(), "94356063238de3893ea019e379184b5407a60058b75933275020dc709cd8ca2a")
    }

    func testSwappingAssetsNotChangeAccount() throws {
        let assetIn: HydraDx.AssetId = 1_000_062
        let assetOut: HydraDx.AssetId = 1_000_034

        let accountId = try HydraXYK.deriveAccount(from: assetIn, asset2: assetOut)
        let accountIdReversed = try HydraXYK.deriveAccount(from: assetOut, asset2: assetIn)

        XCTAssertEqual(accountId, accountIdReversed)
    }
}
