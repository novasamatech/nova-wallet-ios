import XCTest
@testable import novawallet
import SubstrateSdk

final class XcmUniLocationTests: XCTestCase {
    private let ethereum = XcmUni.Junction.globalConsensus(.ethereum(chainId: 1))
    private let wethContract = XcmUni.Junction.accountKey20(
        XcmUni.AccountId20(
            network: .any,
            accountId: try! Data(hexString: "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2")
        )
    )

    func testForeignConsensusFromParachain() {
        let location = XcmUni.AbsoluteLocation(items: [ethereum])

        let result = location.fromChainPointOfView(1000)

        XCTAssertEqual(result, XcmUni.RelativeLocation(parents: 2, items: [ethereum]))
    }

    func testForeignConsensusFromRelaychain() {
        let location = XcmUni.AbsoluteLocation(items: [ethereum])

        let result = location.fromChainPointOfView(nil)

        XCTAssertEqual(result, XcmUni.RelativeLocation(parents: 1, items: [ethereum]))
    }

    func testForeignConsensusErc20FromParachain() {
        let location = XcmUni.AbsoluteLocation(items: [ethereum, wethContract])

        let result = location.fromChainPointOfView(2034)

        XCTAssertEqual(result, XcmUni.RelativeLocation(parents: 2, items: [ethereum, wethContract]))
    }

    func testLocalConsensusKeepsCommonPrefixRule() {
        let usdt = XcmUni.AbsoluteLocation(items: [.parachain(1000), .palletInstance(50), .generalIndex(1984)])

        XCTAssertEqual(
            usdt.fromChainPointOfView(1000),
            XcmUni.RelativeLocation(parents: 0, items: [.palletInstance(50), .generalIndex(1984)])
        )
        XCTAssertEqual(
            usdt.fromChainPointOfView(2034),
            XcmUni.RelativeLocation(parents: 1, items: [.parachain(1000), .palletInstance(50), .generalIndex(1984)])
        )
    }

    func testRawPathParsesEthereumConsensus() throws {
        let path = try json(#"{"globalConsensus": {"ethereum": {"chainId": 1}}}"#)

        let location = try XcmUni.AbsoluteLocation.createWithRawPath(path)

        XCTAssertEqual(location, XcmUni.AbsoluteLocation(items: [ethereum]))
    }

    func testRawPathParsesErc20RegardlessOfKeyOrder() throws {
        let path = try json(
            #"{"accountKey20": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2", "globalConsensus": {"ethereum": {"chainId": 1}}}"#
        )

        let location = try XcmUni.AbsoluteLocation.createWithRawPath(path)

        XCTAssertEqual(location, XcmUni.AbsoluteLocation(items: [ethereum, wethContract]))
    }

    func testRawPathParsesExistingLocalShape() throws {
        let path = try json(#"{"parachainId": 1000, "palletInstance": 50, "generalIndex": "1984"}"#)

        let location = try XcmUni.AbsoluteLocation.createWithRawPath(path)

        XCTAssertEqual(
            location,
            XcmUni.AbsoluteLocation(items: [.parachain(1000), .palletInstance(50), .generalIndex(1984)])
        )
    }

    func testRawPathRejectsUnknownKeys() throws {
        let path = try json(#"{"parents": 2, "globalConsensus": {"ethereum": {"chainId": 1}}}"#)

        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(path))
    }

    func testRawPathRejectsUnsupportedConsensus() throws {
        let path = try json(#"{"globalConsensus": {"polkadot": {}}}"#)

        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(path))
    }

    func testRawPathAcceptsChainIdAsString() throws {
        let path = try json(#"{"globalConsensus": {"ethereum": {"chainId": "1"}}}"#)

        let location = try XcmUni.AbsoluteLocation.createWithRawPath(path)

        XCTAssertEqual(location, XcmUni.AbsoluteLocation(items: [ethereum]))
    }

    func testRawPathRejectsAccountKey20OfWrongLength() throws {
        let path = try json(
            #"{"globalConsensus": {"ethereum": {"chainId": 1}}, "accountKey20": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2ff"}"#
        )

        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(path))
    }

    func testRawPathRejectsWrongValueTypesInsteadOfDroppingThem() throws {
        let stringParachain = try json(#"{"parachainId": "1000"}"#)
        let hugePalletInstance = try json(#"{"parachainId": 1000, "palletInstance": 300}"#)
        let numericGeneralIndex = try json(#"{"parachainId": 1000, "palletInstance": 50, "generalIndex": 1984}"#)

        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(stringParachain))
        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(hugePalletInstance))
        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(numericGeneralIndex))
    }

    func testRawPathRejectsGeneralKeyTogetherWithGeneralIndex() throws {
        let path = try json(#"{"parachainId": 2000, "generalKey": "0x0080", "generalIndex": "1"}"#)

        XCTAssertThrowsError(try XcmUni.AbsoluteLocation.createWithRawPath(path))
    }

    private func json(_ string: String) throws -> JSON {
        try JSONDecoder().decode(JSON.self, from: Data(string.utf8))
    }
}
