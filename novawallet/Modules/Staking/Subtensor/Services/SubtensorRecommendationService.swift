import Foundation
import Operation_iOS

final class SubtensorRecommendationService {
    let apiOperationFactory: BittensorApiOperationFactoryProtocol
    let chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        chainOperationFactory: SubtensorValidatorChainOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.apiOperationFactory = apiOperationFactory
        self.chainOperationFactory = chainOperationFactory
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

extension SubtensorRecommendationGeneration {
    func shownAge(at now: TimeInterval = BittensorMonotonicClock.now()) -> TimeInterval {
        TimeInterval(ageSeconds) + max(0, now - receivedAt)
    }
}

extension SubtensorRankedSubnets {
    func subnet(for netuid: UInt16) -> SubtensorRankedSubnet? {
        items.first { $0.netuid == netuid }
    }
}

private extension SubtensorRecommendationService {
    struct Candidate {
        let recommendationClass: SubtensorRecommendationClass
        let path: String
        let pair: SubtensorHotkeySubnet
        let recommendation: BittensorApi.Recommendation
    }

    struct ParsedGeneration {
        let generation: SubtensorRecommendationGeneration
        let gates: SubtensorClientGates
        let topN: Int
        let candidates: [Candidate]
        let reader: DecimalReader
    }

    static func parse(
        _ response: BittensorApiResult<BittensorApi.RecommendationCollection>,
        logger: LoggerProtocol
    ) throws -> ParsedGeneration {
        let meta = response.value.meta
        let classes = response.value.classes
        let reader = DecimalReader(route: "/recommendations", requestId: response.requestId)

        let groups: [(SubtensorRecommendationClass, String, [BittensorApi.Recommendation])] = [
            (.stable, "stable", classes.stable),
            (.balanced, "balanced", classes.balanced),
            (.higherUpside, "higherUpside", classes.higherUpside)
        ]

        var candidates: [Candidate] = []

        for (recommendationClass, name, recommendations) in groups {
            for (index, recommendation) in recommendations.enumerated() {
                let path = "classes.\(name)[\(index)]"

                guard let hotkey = try? recommendation.hotkey.toAccountId(
                    using: .substrate(SubstrateConstants.genericAddressPrefix)
                ) else {
                    logger.warning("Skipped the recommendation at \(path) with an undecodable hotkey")
                    continue
                }

                let candidate = Candidate(
                    recommendationClass: recommendationClass,
                    path: path,
                    pair: SubtensorHotkeySubnet(hotkey: hotkey, netuid: recommendation.netuid),
                    recommendation: recommendation
                )

                candidates.append(candidate)
            }
        }

        return try ParsedGeneration(
            generation: makeGeneration(
                meta.generation,
                component: meta.components.recommendations,
                completeness: meta.completeness,
                receivedAt: response.receivedAt,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            gates: reader.clientGates(meta.clientGates),
            topN: meta.topN,
            candidates: candidates,
            reader: reader
        )
    }

    static func verify(
        _ parsed: ParsedGeneration,
        snapshot: SubtensorValidatorChainSnapshot
    ) throws -> SubtensorVerifiedRecommendations {
        var classes: [SubtensorRecommendationClass: [SubtensorRecommendedPair]] = [
            .stable: [],
            .balanced: [],
            .higherUpside: []
        ]

        var droppedByGate: [SubtensorRecommendationGate: Int] = [:]

        for candidate in parsed.candidates {
            switch SubtensorRecommendationVerifier.verify(candidate.pair, snapshot: snapshot, gates: parsed.gates) {
            case let .verified(verification):
                let pair = try parsed.reader.pair(
                    candidate.recommendation,
                    hotkey: candidate.pair.hotkey,
                    path: candidate.path,
                    verification: verification
                )

                classes[candidate.recommendationClass, default: []].append(pair)
            case let .dropped(gate):
                droppedByGate[gate, default: 0] += 1
            }
        }

        return SubtensorVerifiedRecommendations(
            generation: parsed.generation,
            clientGates: parsed.gates,
            topN: parsed.topN,
            classes: classes,
            droppedByGate: droppedByGate,
            verifiedAtBlock: snapshot.blockNumber
        )
    }

    static func makeRankedSubnets(
        from response: BittensorApiResult<BittensorApi.SubnetRankingCollection>
    ) throws -> (subnets: SubtensorRankedSubnets, gates: SubtensorClientGates) {
        let meta = response.value.meta
        let reader = DecimalReader(route: "/recommendations/subnets", requestId: response.requestId)

        let gates = try reader.clientGates(meta.clientGates)

        let items = try response.value.items.enumerated().map { index, item in
            try reader.rankedSubnet(item, "items[\(index)]")
        }

        let subnets = SubtensorRankedSubnets(
            generation: makeGeneration(
                meta.generation,
                component: meta.components.recommendations,
                completeness: meta.completeness,
                receivedAt: response.receivedAt,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            policy: policy(meta.policy),
            items: items
        )

        return (subnets, gates)
    }

    static func logDrops(of recommendations: SubtensorVerifiedRecommendations, total: Int, logger: LoggerProtocol) {
        let dropped = recommendations.droppedByGate
        let generation = recommendations.generation.id
        let block = recommendations.verifiedAtBlock

        logger.debug(
            "Subtensor recommendations \(generation) verified at block \(block): \(total) pairs, dropped " +
                "noCurrentUid \(dropped[.noCurrentUid] ?? 0), noPermit \(dropped[.noPermit] ?? 0), " +
                "takeAboveMax \(dropped[.takeAboveMax] ?? 0), inactive \(dropped[.inactive] ?? 0)"
        )
    }
}

extension SubtensorRecommendationService: SubtensorRecommendationServiceProtocol {
    func createVerifiedRecommendationsWrapper() -> CompoundOperationWrapper<SubtensorVerifiedRecommendations> {
        let responseWrapper = apiOperationFactory.createRecommendationsWrapper()
        let chainOperationFactory = chainOperationFactory
        let logger = logger

        let parseOperation = ClosureOperation<ParsedGeneration> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.parse(response, logger: logger)
        }

        parseOperation.addDependency(responseWrapper.targetOperation)

        let snapshotWrapper: CompoundOperationWrapper<SubtensorValidatorChainSnapshot> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let pairs = try parseOperation.extractNoCancellableResultData().candidates.map(\.pair)

                return chainOperationFactory.createChainSnapshotWrapper(
                    for: SubtensorRecommendationVerifier.chainQuery(for: pairs)
                )
            }

        snapshotWrapper.addDependency(operations: [parseOperation])

        let verifyOperation = ClosureOperation<SubtensorVerifiedRecommendations> {
            let parsed = try parseOperation.extractNoCancellableResultData()
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            let recommendations = try Self.verify(parsed, snapshot: snapshot)

            Self.logDrops(of: recommendations, total: parsed.candidates.count, logger: logger)

            return recommendations
        }

        verifyOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: verifyOperation,
            dependencies: responseWrapper.allOperations + [parseOperation] + snapshotWrapper.allOperations
        )
    }

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets> {
        let responseWrapper = apiOperationFactory.createRankedSubnetsWrapper()

        let mappingOperation = ClosureOperation<SubtensorRankedSubnets> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeRankedSubnets(from: response).subnets
        }

        mappingOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: mappingOperation)
    }

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets> {
        apiOperationFactory.peekRankedSubnets().map { try Self.makeRankedSubnets(from: $0).subnets }
    }

    func createClientGatesWrapper() -> CompoundOperationWrapper<SubtensorClientGates> {
        let responseWrapper = apiOperationFactory.createRankedSubnetsWrapper()

        let gatesOperation = ClosureOperation<SubtensorClientGates> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeRankedSubnets(from: response).gates
        }

        gatesOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: gatesOperation)
    }

    func cachedClientGates() -> HTTPCachePeek<SubtensorClientGates> {
        apiOperationFactory.peekRankedSubnets().map { try Self.makeRankedSubnets(from: $0).gates }
    }
}
