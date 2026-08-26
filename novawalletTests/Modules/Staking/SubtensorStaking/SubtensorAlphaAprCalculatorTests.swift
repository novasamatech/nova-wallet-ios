import XCTest
@testable import novawallet
import BigInt

final class SubtensorAlphaAprCalculatorTests: XCTestCase {
    let perBlockEmission = BigUInt(1_000_000_000)
    let apexAlphaOut = BigUInt(2_534_184_037_427_779)
    let blockmachineAlphaOut = BigUInt(2_743_327_814_866_156)
    let chutesAlphaOut = BigUInt(3_287_273_739_407_949)
    let defaultOwnerCut = SubtensorStakingPallet.defaultSubnetOwnerCut
    let defaultTake: UInt16 = 11796

    func testApexGoldenWithoutTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: apexAlphaOut,
                ownerCut: defaultOwnerCut,
                take: 0
            ),
            425_180
        )
    }

    func testApexGoldenWithDefaultTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: apexAlphaOut,
                ownerCut: defaultOwnerCut,
                take: defaultTake
            ),
            348_650
        )
    }

    func testBlockmachineGoldenWithoutTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: blockmachineAlphaOut,
                ownerCut: defaultOwnerCut,
                take: 0
            ),
            392_766
        )
    }

    func testBlockmachineGoldenWithDefaultTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: blockmachineAlphaOut,
                ownerCut: defaultOwnerCut,
                take: defaultTake
            ),
            322_069
        )
    }

    func testChutesGoldenWithoutTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: chutesAlphaOut,
                ownerCut: defaultOwnerCut,
                take: 0
            ),
            327_774
        )
    }

    func testChutesGoldenWithDefaultTake() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: chutesAlphaOut,
                ownerCut: defaultOwnerCut,
                take: defaultTake
            ),
            268_776
        )
    }

    func testDeadSubnetWithZeroAlphaOutHasNoApr() {
        XCTAssertNil(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: 0,
                alphaOut: 0,
                ownerCut: defaultOwnerCut,
                take: defaultTake
            )
        )
    }

    func testZeroEmissionWithLiveAlphaOutYieldsZeroApr() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: 0,
                alphaOut: apexAlphaOut,
                ownerCut: defaultOwnerCut,
                take: defaultTake
            ),
            0
        )
    }

    func testFullOwnerCutYieldsZeroApr() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: apexAlphaOut,
                ownerCut: SubtensorStakingPallet.perU16Denominator,
                take: 0
            ),
            0
        )
    }

    func testFullTakeYieldsZeroApr() {
        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(
                alphaOutEmission: perBlockEmission,
                alphaOut: apexAlphaOut,
                ownerCut: 0,
                take: SubtensorStakingPallet.perU16Denominator
            ),
            0
        )
    }

    func testDynamicInfoOverloadUsesEmissionOperands() {
        let info = makeDynamicInfo(
            alphaOutEmission: perBlockEmission,
            alphaOut: apexAlphaOut,
            tempo: 99
        )

        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(for: info, ownerCut: defaultOwnerCut, take: 0),
            425_180
        )
    }

    func testTempoNeverEntersTheFormula() {
        let fastTempoInfo = makeDynamicInfo(
            alphaOutEmission: perBlockEmission,
            alphaOut: blockmachineAlphaOut,
            tempo: 99
        )

        let slowTempoInfo = makeDynamicInfo(
            alphaOutEmission: perBlockEmission,
            alphaOut: blockmachineAlphaOut,
            tempo: 7200
        )

        XCTAssertEqual(
            SubtensorAlphaAprCalculator.aprPpm(for: fastTempoInfo, ownerCut: defaultOwnerCut, take: defaultTake),
            SubtensorAlphaAprCalculator.aprPpm(for: slowTempoInfo, ownerCut: defaultOwnerCut, take: defaultTake)
        )
    }

    private func makeDynamicInfo(
        alphaOutEmission: Balance,
        alphaOut: Balance,
        tempo: UInt16
    ) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: 1,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data("Apex".utf8),
            tokenSymbol: Data("α".utf8),
            tempo: tempo,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: 0,
            alphaOut: alphaOut,
            taoIn: 0,
            alphaOutEmission: alphaOutEmission,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: .null
        )
    }
}
