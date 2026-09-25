import XCTest
@testable import novawallet
import BigInt
import Operation_iOS

final class BittensorFixtureChainSnapshotTests: XCTestCase {
    func testFixtureVerificationDropsOnlyTheTakeGatePairAndKeepsTheFrozenRootPairs() throws {
        let collection = try fetchRecommendations()
        let gates = collection.meta.clientGates
        let maxTake = try BittensorApiDecimal.fraction(gates.maxTake)
        let recommendations = collection.classes.stable + collection.classes.balanced + collection.classes.higherUpside

        let pairs = try recommendations.map {
            SubtensorHotkeySubnet(
                hotkey: try $0.hotkey.toAccountId(using: .substrate(SubstrateConstants.genericAddressPrefix)),
                netuid: $0.netuid
            )
        }

        let snapshot = try fetch(
            BittensorFixtureChainSnapshot().createChainSnapshotWrapper(
                for: SubtensorValidatorChainQuery(pairs: pairs, includesHotkeyAlpha: false)
            )
        )

        let drops = zip(recommendations, pairs).compactMap { recommendation, pair in
            gate(for: pair, snapshot: snapshot, gates: gates, maxTake: maxTake).map {
                "\(recommendation.validatorName ?? "")@\(recommendation.netuid):\($0)"
            }
        }

        let rootLastUpdates = try XCTUnwrap(snapshot.lastUpdates[0])
        let rootCutoff = try XCTUnwrap(snapshot.effectiveActivityCutoffs[0])
        let rootStatuses = pairs.filter { $0.netuid == 0 }.map {
            SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: $0)
        }

        XCTAssertEqual(drops, ["Delta Relay@64:takeAboveMax"])
        XCTAssertEqual(rootStatuses.count, 3)
        XCTAssertTrue(rootStatuses.allSatisfy { $0 != nil && $0?.isActive == nil && $0?.hasPermit == nil })
        XCTAssertTrue(rootLastUpdates.allSatisfy { UInt64(snapshot.blockNumber) - $0 > rootCutoff })
    }

    private func gate(
        for pair: SubtensorHotkeySubnet,
        snapshot: SubtensorValidatorChainSnapshot,
        gates: BittensorApi.ClientGates,
        maxTake: BigRational
    ) -> SubtensorRecommendationGate? {
        guard let status = SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair) else {
            return .noCurrentUid
        }

        let isRoot = pair.netuid == SubtensorStakingPallet.rootNetuid

        if !isRoot, gates.requirePermit, status.hasPermit != true {
            return .noPermit
        }

        if SubtensorTakeGate.exceedsMax(take: snapshot.takes[pair.hotkey] ?? UInt16.max, maxTake: maxTake) {
            return .takeAboveMax
        }

        if !isRoot, gates.requireActiveWithinCutoff, status.isActive != true {
            return .inactive
        }

        return nil
    }

    private func fetchRecommendations() throws -> BittensorApi.RecommendationCollection {
        let request = BittensorApiRequest(
            method: .get,
            path: "/recommendations",
            pathTemplate: "/recommendations",
            queryItems: [],
            jsonBody: nil
        )

        let response = try fetch(BittensorApiFixtureTransport().createResponseWrapper(for: request))

        return try JSONDecoder().decode(BittensorApi.RecommendationCollection.self, from: response.body)
    }

    private func fetch<T>(_ wrapper: CompoundOperationWrapper<T>) throws -> T {
        OperationQueue().addOperations(wrapper.allOperations, waitUntilFinished: true)

        return try wrapper.targetOperation.extractNoCancellableResultData()
    }
}
