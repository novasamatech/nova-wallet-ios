import XCTest
@testable import novawallet
import BigInt
import SubstrateSdk

final class SubtensorPreflightValuesTests: XCTestCase {
    let nominatorMinFactorHex = "0x8096980000000000"
    let claimableThresholdBitsHex = "0x0000000020a107000000000000000000"

    func testInitialMinStakeConstantDecodesFromMetadata() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let operation = PrimitiveConstantOperation<Balance>(
            path: SubtensorStakingPallet.initialMinStakePath
        )

        operation.codingFactory = codingFactory

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(try operation.extractNoCancellableResultData(), BigUInt(2_000_000))
    }

    func testNominatorMinFactorFixtureDecodes() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let operation = StorageDecodingOperation<StringScaleMapper<Balance>>(
            path: SubtensorStakingPallet.nominatorMinRequiredStakePath,
            data: try Data(hexString: nominatorMinFactorHex)
        )

        operation.codingFactory = codingFactory

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(
            try operation.extractNoCancellableResultData().value,
            BigUInt(10_000_000)
        )
    }

    func testClaimableThresholdFixedPointDecodesFromMetadata() throws {
        let codingFactory = try RuntimeCodingServiceStub.createBittensorCodingFactory()

        let operation = StorageDecodingOperation<SubtensorStakingPallet.FixedPoint96F32>(
            path: SubtensorStakingPallet.rootClaimableThresholdPath,
            data: try Data(hexString: claimableThresholdBitsHex)
        )

        operation.codingFactory = codingFactory

        OperationQueue().addOperations([operation], waitUntilFinished: true)

        XCTAssertEqual(
            try operation.extractNoCancellableResultData().bits,
            BigUInt(500_000) << 32
        )
    }

    func testEffectiveNominatorMinStakeMatchesChainDerivation() {
        let effective = SubtensorStakingPreflight.effectiveNominatorMinStake(
            minStake: BigUInt(2_000_000),
            factor: BigUInt(10_000_000)
        )

        XCTAssertEqual(effective, BigUInt(20_000_000))
    }

    func testZeroFactorDisablesNominatorMinStake() {
        let effective = SubtensorStakingPreflight.effectiveNominatorMinStake(
            minStake: BigUInt(2_000_000),
            factor: 0
        )

        XCTAssertEqual(effective, 0)
    }

    func testUnsetClaimableThresholdFallsBackToChainDefault() {
        XCTAssertEqual(
            SubtensorStakingPreflight.rootClaimableThreshold(fromBits: nil),
            BigUInt(500_000)
        )
    }

    func testClaimableThresholdBitsConvertToRao() {
        XCTAssertEqual(
            SubtensorStakingPreflight.rootClaimableThreshold(fromBits: BigUInt(500_000) << 32),
            BigUInt(500_000)
        )
    }

    func testClaimableThresholdFractionalBitsFloor() {
        XCTAssertEqual(
            SubtensorStakingPreflight.rootClaimableThreshold(fromBits: (BigUInt(500_000) << 32) + 7),
            BigUInt(500_000)
        )
    }
}
