import BigInt
@testable import novawallet
import XCTest

final class SubtensorRootAprCalculatorTests: XCTestCase {
    private let taoWeight = BigUInt(3_320_413_933_267_719_290)
    private let rootTao = BigUInt(5_403_546_305_524_763)
    private let rootStake = BigUInt(5_575_547_743_380_273)
    private let ownerCut: UInt16 = 11796

    private func makeSubnet(
        netuid: UInt16,
        alphaIn: Balance,
        alphaOut: Balance,
        price: Balance,
        alphaOutEmission: Balance = 1_000_000_000,
        movingPriceBits: Balance = 0,
        ownerCutEnabled: Bool = true
    ) -> SubtensorRootAprCalculator.Subnet {
        SubtensorRootAprCalculator.Subnet(
            netuid: netuid,
            alphaOutEmission: alphaOutEmission,
            alphaIssuance: alphaIn + alphaOut,
            price: price,
            movingPriceBits: movingPriceBits,
            ownerCutEnabled: ownerCutEnabled
        )
    }

    private func makeChutes() -> SubtensorRootAprCalculator.Subnet {
        makeSubnet(
            netuid: 64,
            alphaIn: 2_740_727_097_512_439,
            alphaOut: 3_287_273_739_407_949,
            price: 75_911_365
        )
    }

    private func makeApex() -> SubtensorRootAprCalculator.Subnet {
        makeSubnet(
            netuid: 1,
            alphaIn: 3_224_234_104_288_074,
            alphaOut: 2_534_184_037_427_779,
            price: 7_754_506
        )
    }

    /// operands captured from finney at block 8_926_954 next to the runtime's own `RootProp[netuid]`,
    /// which is a U96F32 fixed point — 32 fractional bits
    private func capturedRootPropBits(alphaIssuance: Balance) -> BigUInt {
        let proportion = SubtensorRootAprCalculator.rootProportion(
            taoWeight: 3_320_413_933_267_719_290,
            rootTao: 5_403_741_979_798_556,
            alphaIssuance: alphaIssuance
        )

        let fixedPointOne = BigUInt(1) << SubtensorStakingPallet.fixedPointFractionalBits

        return proportion * fixedPointOne / SubtensorRootAprCalculator.proportionScale
    }

    private func makeParams(
        subnets: [SubtensorRootAprCalculator.Subnet],
        ownerCut: UInt16? = nil,
        rootStake: BigUInt? = nil
    ) -> SubtensorRootAprCalculator.Params {
        SubtensorRootAprCalculator.Params(
            taoWeight: taoWeight,
            rootTao: rootTao,
            rootStake: rootStake ?? self.rootStake,
            ownerCut: ownerCut ?? self.ownerCut,
            subnets: subnets
        )
    }

    func testRootProportionGoldenForTheChutesReserves() {
        let proportion = SubtensorRootAprCalculator.rootProportion(
            taoWeight: taoWeight,
            rootTao: rootTao,
            alphaIssuance: 2_740_727_097_512_439 + 3_287_273_739_407_949
        )

        XCTAssertEqual(proportion, BigUInt(138_935_647_318_674_340))
    }

    func testRootProportionGoldenForTheApexReserves() {
        let proportion = SubtensorRootAprCalculator.rootProportion(
            taoWeight: taoWeight,
            rootTao: rootTao,
            alphaIssuance: 3_224_234_104_288_074 + 2_534_184_037_427_779
        )

        XCTAssertEqual(proportion, BigUInt(144_500_100_149_184_578))
    }

    func testRootProportionReproducesTheChainReportedValueForChutes() {
        let bits = capturedRootPropBits(alphaIssuance: 2_744_662_185_041_540 + 3_288_587_745_740_282)

        XCTAssertEqual(bits, BigUInt(596_295_566))
    }

    func testRootProportionReproducesTheChainReportedValueForApexWithinOneUlp() {
        let bits = capturedRootPropBits(alphaIssuance: 3_239_523_995_246_776 + 2_523_641_023_527_718)
        let chainReported = BigUInt(620_205_051)
        let delta = bits > chainReported ? bits - chainReported : chainReported - bits

        XCTAssertLessThanOrEqual(delta, 1)
    }

    func testRootProportionSaturatesWhenSubnetHasNoAlphaIssuance() {
        let proportion = SubtensorRootAprCalculator.rootProportion(
            taoWeight: taoWeight,
            rootTao: rootTao,
            alphaIssuance: 0
        )

        XCTAssertEqual(proportion, SubtensorRootAprCalculator.proportionScale)
    }

    func testRootProportionIsZeroWhenBothSidesAreEmpty() {
        let proportion = SubtensorRootAprCalculator.rootProportion(
            taoWeight: taoWeight,
            rootTao: 0,
            alphaIssuance: 0
        )

        XCTAssertEqual(proportion, 0)
    }

    func testSingleSubnetGrossAprMatchesHandDerivedValue() {
        let ppm = SubtensorRootAprCalculator.aprPpm(for: makeParams(subnets: [makeChutes()]))

        XCTAssertEqual(ppm, BigUInt(2038))
    }

    func testSingleSubnetAprNetsTheDelegateTake() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes()]),
            take: 11796
        )

        XCTAssertEqual(ppm, BigUInt(1671))
    }

    func testTwoSubnetGrossAprMatchesHandDerivedValue() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex()])
        )

        XCTAssertEqual(ppm, BigUInt(2254))
    }

    func testTwoSubnetAprNetsTheDelegateTake() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex()]),
            take: 11796
        )

        XCTAssertEqual(ppm, BigUInt(1848))
    }

    func testSubnetOrderDoesNotChangeApr() {
        let forward = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex()])
        )

        let reversed = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeApex(), makeChutes()])
        )

        XCTAssertEqual(forward, reversed)
    }

    func testNonEmittingSubnetDoesNotChangeApr() {
        let idle = makeSubnet(
            netuid: 36,
            alphaIn: 1_000_000_000_000_000,
            alphaOut: 2_000_000_000_000_000,
            price: 50_000_000,
            alphaOutEmission: 0
        )

        let withIdle = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex(), idle])
        )

        XCTAssertEqual(withIdle, BigUInt(2254))
    }

    func testRootSubnetIsExcludedFromItsOwnEmissionShare() {
        let root = makeSubnet(
            netuid: 0,
            alphaIn: 0,
            alphaOut: rootStake,
            price: 1_000_000_000,
            alphaOutEmission: 1_000_000_000
        )

        let withRoot = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex(), root])
        )

        XCTAssertEqual(withRoot, BigUInt(2254))
    }

    func testDisabledOwnerCutRaisesAprAboveTheCutRetainedValue() {
        let uncut = makeSubnet(
            netuid: 64,
            alphaIn: 2_740_727_097_512_439,
            alphaOut: 3_287_273_739_407_949,
            price: 75_911_365,
            ownerCutEnabled: false
        )

        let ppm = SubtensorRootAprCalculator.aprPpm(for: makeParams(subnets: [uncut]))

        XCTAssertEqual(ppm, BigUInt(2485))
    }

    func testFullOwnerCutLeavesNothingForRootStakers() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex()], ownerCut: 65535)
        )

        XCTAssertEqual(ppm, BigUInt(0))
    }

    func testFullDelegateTakeLeavesNothingForTheNominator() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes(), makeApex()]),
            take: 65535
        )

        XCTAssertEqual(ppm, BigUInt(0))
    }

    func testAprIsNilWhenNoRootStakeOutstanding() {
        let ppm = SubtensorRootAprCalculator.aprPpm(
            for: makeParams(subnets: [makeChutes()], rootStake: 0)
        )

        XCTAssertNil(ppm)
    }

    func testAprIsZeroWhenNoSubnetEmits() {
        let idle = makeSubnet(
            netuid: 64,
            alphaIn: 2_740_727_097_512_439,
            alphaOut: 3_287_273_739_407_949,
            price: 75_911_365,
            alphaOutEmission: 0
        )

        let ppm = SubtensorRootAprCalculator.aprPpm(for: makeParams(subnets: [idle]))

        XCTAssertEqual(ppm, BigUInt(0))
    }

    func testAprDecreasesMonotonicallyInTheDelegateTake() {
        let params = makeParams(subnets: [makeChutes(), makeApex()])

        let takes: [UInt16] = [0, 6553, 11796, 32767, 65535]

        let values = takes.compactMap { SubtensorRootAprCalculator.aprPpm(for: params, take: $0) }

        XCTAssertEqual(values.count, takes.count)
        XCTAssertEqual(values, values.sorted(by: >))
        XCTAssertEqual(values.last, BigUInt(0))
    }

    func testRootEmissionIsPausedWhenSummedMovingPriceIsAtTheCutoff() {
        let subnets = [
            makeSubnet(
                netuid: 64,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                movingPriceBits: 2_147_483_648
            ),
            makeSubnet(
                netuid: 1,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                movingPriceBits: 2_147_483_648
            )
        ]

        XCTAssertTrue(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: subnets))
    }

    func testRootEmissionIsActiveWhenSummedMovingPriceExceedsTheCutoff() {
        let subnets = [
            makeSubnet(
                netuid: 64,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                movingPriceBits: 2_147_483_648
            ),
            makeSubnet(
                netuid: 1,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                movingPriceBits: 2_147_483_649
            )
        ]

        XCTAssertFalse(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: subnets))
    }

    func testPausedGateIgnoresNonEmittingSubnets() {
        let subnets = [
            makeSubnet(
                netuid: 64,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                movingPriceBits: 5_000_000_000,
                ownerCutEnabled: true
            ),
            makeSubnet(
                netuid: 36,
                alphaIn: 1,
                alphaOut: 1,
                price: 1,
                alphaOutEmission: 0,
                movingPriceBits: 9_000_000_000
            )
        ]

        XCTAssertFalse(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: subnets))

        let onlyIdle = [subnets[1]]

        XCTAssertTrue(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: onlyIdle))
    }

    func testPausedGateIgnoresRootSubnet() {
        let subnets = [
            makeSubnet(
                netuid: 0,
                alphaIn: 1,
                alphaOut: 1,
                price: 1_000_000_000,
                movingPriceBits: 9_000_000_000
            )
        ]

        XCTAssertTrue(SubtensorRootAprCalculator.isRootEmissionPaused(subnets: subnets))
    }
}
