import BigInt
import Cuckoo
@testable import novawallet
import SubstrateSdk
import XCTest

final class SubtensorRewardCalculatorServiceTests: XCTestCase {
    private enum TestError: Error {
        case unreachable
    }

    private func makeDynamicInfo(
        netuid: UInt16,
        alphaIn: Balance,
        alphaOut: Balance,
        taoIn: Balance,
        alphaOutEmission: Balance,
        movingPrice: JSON = .null
    ) -> SubtensorStakingPallet.DynamicInfo {
        SubtensorStakingPallet.DynamicInfo(
            netuid: netuid,
            ownerHotkey: Data(repeating: 0, count: 32),
            ownerColdkey: Data(repeating: 0, count: 32),
            subnetName: Data("subnet".utf8),
            tokenSymbol: Data("α".utf8),
            tempo: 360,
            lastStep: 0,
            blocksSinceLastStep: 0,
            emission: 0,
            alphaIn: alphaIn,
            alphaOut: alphaOut,
            taoIn: taoIn,
            alphaOutEmission: alphaOutEmission,
            alphaInEmission: 0,
            taoInEmission: 0,
            pendingAlphaEmission: 0,
            pendingRootEmission: 0,
            subnetVolume: 0,
            networkRegisteredAt: 0,
            subnetIdentity: nil,
            movingPrice: movingPrice
        )
    }

    private func makeSubnetsInfo(
        includingRoot: Bool = true,
        movingPrice: JSON = .null,
        ownerCut: UInt16 = SubtensorStakingPallet.defaultSubnetOwnerCut
    ) -> SubtensorSubnetsInfo {
        var subnets: [SubtensorStakingPallet.DynamicInfo] = []

        if includingRoot {
            subnets.append(
                makeDynamicInfo(
                    netuid: 0,
                    alphaIn: 0,
                    alphaOut: 5_575_547_743_380_273,
                    taoIn: 5_403_546_305_524_763,
                    alphaOutEmission: 0
                )
            )
        }

        subnets.append(
            makeDynamicInfo(
                netuid: 64,
                alphaIn: 2_740_727_097_512_439,
                alphaOut: 3_287_273_739_407_949,
                taoIn: 111,
                alphaOutEmission: 1_000_000_000,
                movingPrice: movingPrice
            )
        )

        return SubtensorSubnetsInfo(
            subnets: subnets,
            prices: [0: 1_000_000_000, 64: 75_911_365],
            subtokenEnabled: [64],
            ownerCut: ownerCut
        )
    }

    private func makeInputs() -> SubtensorRootAprInputs {
        SubtensorRootAprInputs(taoWeight: 3_320_413_933_267_719_290)
    }

    private func makeService(
        subnetsResult: Result<SubtensorSubnetsInfo, Error>,
        inputsResult: Result<SubtensorRootAprInputs, Error>
    ) -> SubtensorRewardCalculatorService {
        let subnetsService = MockSubtensorSubnetsServiceProtocol()
        let inputsService = MockSubtensorRootAprInputsServiceProtocol()

        stub(subnetsService) { stub in
            when(stub.fetchSubnetsInfo(runningCompletionIn: any(), completion: any())).then { queue, closure in
                queue.async { closure(subnetsResult) }
            }
        }

        stub(inputsService) { stub in
            when(stub.fetchInputs(runningCompletionIn: any(), completion: any())).then { queue, closure in
                queue.async { closure(inputsResult) }
            }
        }

        return SubtensorRewardCalculatorService(
            subnetsService: subnetsService,
            inputsService: inputsService,
            logger: Logger.shared
        )
    }

    private func fetchEngine(
        using service: SubtensorRewardCalculatorService
    ) throws -> Result<SubtensorRewardCalculatorEngineProtocol, Error> {
        let expectation = XCTestExpectation()

        var received: Result<SubtensorRewardCalculatorEngineProtocol, Error>?

        service.fetchEngine(runningCompletionIn: .main) { result in
            received = result
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10)

        return try XCTUnwrap(received)
    }

    func testParamsTakeRootReservesFromTheRootSubnetEntry() throws {
        let params = try XCTUnwrap(
            SubtensorRewardCalculatorService.makeParams(
                subnetsInfo: makeSubnetsInfo(),
                inputs: makeInputs()
            )
        )

        XCTAssertEqual(params.rootTao, BigUInt(5_403_546_305_524_763))
        XCTAssertEqual(params.rootStake, BigUInt(5_575_547_743_380_273))
        XCTAssertEqual(params.taoWeight, BigUInt(3_320_413_933_267_719_290))
        XCTAssertEqual(params.ownerCut, 11796)
    }

    func testParamsTakeOwnerCutFromTheSubnetsInfo() throws {
        let params = try XCTUnwrap(
            SubtensorRewardCalculatorService.makeParams(
                subnetsInfo: makeSubnetsInfo(ownerCut: 20000),
                inputs: makeInputs()
            )
        )

        XCTAssertEqual(params.ownerCut, 20000)
    }

    func testParamsSumAlphaIssuanceFromBothReserves() throws {
        let params = try XCTUnwrap(
            SubtensorRewardCalculatorService.makeParams(
                subnetsInfo: makeSubnetsInfo(),
                inputs: makeInputs()
            )
        )

        let chutes = try XCTUnwrap(params.subnets.first { $0.netuid == 64 })

        XCTAssertEqual(chutes.alphaIssuance, BigUInt(6_028_000_836_920_388))
        XCTAssertEqual(chutes.price, BigUInt(75_911_365))
        XCTAssertTrue(chutes.ownerCutEnabled)
    }

    func testParamsDecodeMovingPriceBits() throws {
        let movingPrice = JSON.dictionaryValue(["bits": .stringValue("5000000000")])

        let params = try XCTUnwrap(
            SubtensorRewardCalculatorService.makeParams(
                subnetsInfo: makeSubnetsInfo(movingPrice: movingPrice),
                inputs: makeInputs()
            )
        )

        let chutes = try XCTUnwrap(params.subnets.first { $0.netuid == 64 })

        XCTAssertEqual(chutes.movingPriceBits, BigUInt(5_000_000_000))
    }

    func testParamsAreUnavailableWhenAnEmittingSubnetHasNoPrice() {
        var subnetsInfo = makeSubnetsInfo()

        subnetsInfo = SubtensorSubnetsInfo(
            subnets: subnetsInfo.subnets,
            prices: [0: 1_000_000_000],
            subtokenEnabled: subnetsInfo.subtokenEnabled,
            ownerCut: subnetsInfo.ownerCut
        )

        let params = SubtensorRewardCalculatorService.makeParams(
            subnetsInfo: subnetsInfo,
            inputs: makeInputs()
        )

        XCTAssertNil(params)
    }

    func testParamsAreUnavailableWithoutTheRootSubnet() {
        let params = SubtensorRewardCalculatorService.makeParams(
            subnetsInfo: makeSubnetsInfo(includingRoot: false),
            inputs: makeInputs()
        )

        XCTAssertNil(params)
    }

    func testEngineReturnsGrossAprWhenRootEmissionIsActive() throws {
        let movingPrice = JSON.dictionaryValue(["bits": .stringValue("5000000000")])

        let service = makeService(
            subnetsResult: .success(makeSubnetsInfo(movingPrice: movingPrice)),
            inputsResult: .success(makeInputs())
        )

        let engine = try fetchEngine(using: service).get()

        XCTAssertFalse(engine.isRootEmissionPaused)
        XCTAssertEqual(engine.rootAnnualReturn(), Decimal(string: "0.002038"))
        XCTAssertEqual(engine.rootAnnualReturn(take: 11796), Decimal(string: "0.001671"))
    }

    func testEngineWithholdsAprWhileRootEmissionIsRecycled() throws {
        let movingPrice = JSON.dictionaryValue(["bits": .stringValue("2000000000")])

        let service = makeService(
            subnetsResult: .success(makeSubnetsInfo(movingPrice: movingPrice)),
            inputsResult: .success(makeInputs())
        )

        let engine = try fetchEngine(using: service).get()

        XCTAssertTrue(engine.isRootEmissionPaused)
        XCTAssertNil(engine.rootAnnualReturn())
        XCTAssertNil(engine.rootAnnualReturn(take: 11796))
    }

    func testSubnetsFailurePropagatesInsteadOfProducingAnEngine() throws {
        let service = makeService(
            subnetsResult: .failure(TestError.unreachable),
            inputsResult: .success(makeInputs())
        )

        let result = try fetchEngine(using: service)

        XCTAssertThrowsError(try result.get())
    }

    func testStorageInputsFailurePropagatesInsteadOfProducingAnEngine() throws {
        let movingPrice = JSON.dictionaryValue(["bits": .stringValue("5000000000")])

        let service = makeService(
            subnetsResult: .success(makeSubnetsInfo(movingPrice: movingPrice)),
            inputsResult: .failure(TestError.unreachable)
        )

        let result = try fetchEngine(using: service)

        XCTAssertThrowsError(try result.get())
    }
}
