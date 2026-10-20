import Cuckoo
@testable import novawallet
import Operation_iOS
import XCTest

final class SubtensorMaxApyOperationFactoryTests: XCTestCase {
    private let asOf = Date(timeIntervalSince1970: 1_790_000_000)
    private let rootHotkey = Data(repeating: 0x11, count: 32)
    private let chutesLowerPair = Data(repeating: 0x22, count: 32)
    private let chutesHigherPair = Data(repeating: 0x33, count: 32)
    private let chutesOutsider = Data(repeating: 0x44, count: 32)
    private let templarPair = Data(repeating: 0x55, count: 32)
    private let affinePair = Data(repeating: 0x66, count: 32)

    func testSubnetApyIsItsBestRecommendedPairRate() throws {
        let yields: [UInt16: [AccountId: String]] = [
            0: [rootHotkey: "7.0"],
            64: [chutesLowerPair: "12.5", chutesHigherPair: "31.2", chutesOutsider: "152.4"],
            3: [templarPair: "31.2"]
        ]

        let apy = try run(createOperationFactory(yields: yields).createMaxApyWrapper())

        XCTAssertEqual(apy, [0: rate("0.07"), 64: rate("0.312"), 3: rate("0.312")])
        XCTAssertEqual(apy.values.max(), rate("0.312"))
    }

    func testSubnetsWithoutFreshRecommendedPairYieldHaveNoValue() throws {
        let yields: [UInt16: [AccountId: String]] = [
            0: [rootHotkey: "7.0"],
            64: [chutesOutsider: "152.4"],
            3: [templarPair: "31.2"]
        ]

        let apy = try run(createOperationFactory(yields: yields, stale: [3], failing: [120]).createMaxApyWrapper())

        XCTAssertEqual(apy, [0: rate("0.07")])
    }

    func testDerivationFailsOnlyWhenEveryYieldPageFails() throws {
        let operationFactory = try createOperationFactory(yields: [:], failing: [0, 3, 64, 120])

        XCTAssertThrowsError(try run(operationFactory.createMaxApyWrapper()))
    }

    private func rate(_ value: String) -> Decimal {
        Decimal(string: value)!
    }

    private func recommendation(_ hotkey: AccountId, _ netuid: UInt16) throws -> BittensorApi.Recommendation {
        try BittensorApi.Recommendation(
            netuid: netuid,
            hotkey: hotkey.toAddress(using: .substrate(SubstrateConstants.genericAddressPrefix)),
            clientChecks: [.uid, .validatorPermit, .take, .lastUpdate]
        )
    }

    private func createApiFactory() throws -> MockBittensorApiOperationFactoryProtocol {
        let collection = try BittensorApi.RecommendationCollection(
            meta: BittensorApi.RecommendationMetadata(
                components: .init(recommendations: BittensorApi.AvailableComponent(asOf: asOf, freshness: .fresh)),
                generation: BittensorApi.Generation(sourceBlockNumber: 9_139_880, carriedOverNetuids: []),
                clientGates: BittensorApi.ClientGates(maxTake: "0.18", requirePermit: true, requireActiveWithinCutoff: true)
            ),
            classes: BittensorApi.RecommendationClasses(
                stable: [recommendation(rootHotkey, 0)],
                balanced: [recommendation(chutesLowerPair, 64), recommendation(templarPair, 3)],
                higherUpside: [recommendation(chutesHigherPair, 64), recommendation(affinePair, 120)]
            )
        )
        let result = BittensorApiResult(value: collection, requestId: "request-1", isFromExpiredCache: false)
        let apiFactory = MockBittensorApiOperationFactoryProtocol()
        stub(apiFactory) { stub in
            when(stub.createRecommendationsWrapper()).thenReturn(CompoundOperationWrapper.createWithResult(result))
        }

        return apiFactory
    }

    private func createYieldOperationFactory(
        yields: [UInt16: [AccountId: String]],
        stale: Set<UInt16>,
        failing: Set<UInt16>
    ) -> MockSubtensorYieldOperationFactoryProtocol {
        let yieldOperationFactory = MockSubtensorYieldOperationFactoryProtocol()

        stub(yieldOperationFactory) { stub in
            when(stub.createAlphaYieldsWrapper(for: any())).then { netuid in
                guard !failing.contains(netuid) else {
                    return CompoundOperationWrapper.createWithError(
                        BittensorApiError.unavailable(code: nil, requestId: nil)
                    )
                }

                let stamp = SubtensorBackendStamp(asOf: self.asOf, freshness: stale.contains(netuid) ? .stale : .fresh)

                return CompoundOperationWrapper.createWithResult(
                    SubtensorAlphaYields(
                        netuid: netuid,
                        yields: (yields[netuid] ?? [:]).mapValues {
                            SubtensorReportedYield(reportedRate: $0, stamp: stamp, isReliable: true)
                        },
                        stamp: stamp
                    )
                )
            }
        }

        return yieldOperationFactory
    }

    private func createOperationFactory(
        yields: [UInt16: [AccountId: String]],
        stale: Set<UInt16> = [],
        failing: Set<UInt16> = []
    ) throws -> SubtensorMaxApyOperationFactory {
        SubtensorMaxApyOperationFactory(
            apiOperationFactory: try createApiFactory(),
            yieldOperationFactory: createYieldOperationFactory(yields: yields, stale: stale, failing: failing),
            operationQueue: OperationQueue(),
            logger: Logger.shared
        )
    }

    private func run<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)
        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
