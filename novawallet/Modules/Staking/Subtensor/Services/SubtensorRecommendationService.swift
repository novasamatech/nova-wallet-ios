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

extension SubtensorRankedSubnets {
    func subnet(for netuid: UInt16) -> SubtensorRankedSubnet? {
        items.first { $0.netuid == netuid }
    }
}

private extension SubtensorRecommendationService {
    struct Candidate {
        let recommendationClass: SubtensorRecommendationClass
        let pair: SubtensorHotkeySubnet
    }

    struct ParsedGeneration {
        let generation: SubtensorRecommendationGeneration
        let gates: SubtensorClientGates
        let candidates: [Candidate]
    }

    static func parse(
        _ response: BittensorApiResult<BittensorApi.RecommendationCollection>,
        logger: LoggerProtocol
    ) throws -> ParsedGeneration {
        let meta = response.value.meta
        let classes = response.value.classes
        let reader = BittensorApiFieldReader(route: "/recommendations", requestId: response.requestId)
        let gates = try clientGates(meta.clientGates, reader: reader)

        let groups: [(SubtensorRecommendationClass, String, [BittensorApi.Recommendation])] = [
            (.stable, "stable", classes.stable),
            (.balanced, "balanced", classes.balanced),
            (.higherUpside, "higherUpside", classes.higherUpside)
        ]

        var candidates: [Candidate] = []

        for (recommendationClass, name, recommendations) in groups {
            for (index, recommendation) in recommendations.enumerated() {
                let path = "classes.\(name)[\(index)]"

                try reader.require(recommendation.clientChecks == requiredClientChecks, "\(path).clientChecks")

                guard let hotkey = try? recommendation.hotkey.toAccountId(
                    using: .substrate(SubstrateConstants.genericAddressPrefix)
                ) else {
                    logger.warning("Skipped the recommendation at \(path) with an undecodable hotkey")
                    continue
                }

                let candidate = Candidate(
                    recommendationClass: recommendationClass,
                    pair: SubtensorHotkeySubnet(hotkey: hotkey, netuid: recommendation.netuid)
                )

                candidates.append(candidate)
            }
        }

        return ParsedGeneration(
            generation: makeGeneration(
                meta,
                receivedAt: response.receivedAt,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            gates: gates,
            candidates: candidates
        )
    }

    static func verify(
        _ parsed: ParsedGeneration,
        snapshot: SubtensorValidatorChainSnapshot
    ) -> SubtensorVerifiedRecommendations {
        var classes: [SubtensorRecommendationClass: [SubtensorHotkeySubnet]] = [
            .stable: [],
            .balanced: [],
            .higherUpside: []
        ]

        for candidate in parsed.candidates
            where SubtensorRecommendationVerifier.passesGates(candidate.pair, snapshot: snapshot, gates: parsed.gates) {
            classes[candidate.recommendationClass, default: []].append(candidate.pair)
        }

        return SubtensorVerifiedRecommendations(
            generation: parsed.generation,
            clientGates: parsed.gates,
            classes: classes
        )
    }

    static func makeRankedSubnets(
        from response: BittensorApiResult<BittensorApi.SubnetRankingCollection>
    ) throws -> (subnets: SubtensorRankedSubnets, gates: SubtensorClientGates) {
        let meta = response.value.meta
        let reader = BittensorApiFieldReader(route: "/recommendations/subnets", requestId: response.requestId)

        let gates = try clientGates(meta.clientGates, reader: reader)

        let items = try response.value.items.enumerated().map { index, item in
            try rankedSubnet(item, "items[\(index)]", reader: reader)
        }

        let subnets = SubtensorRankedSubnets(
            generation: makeGeneration(
                meta,
                receivedAt: response.receivedAt,
                isFromExpiredCache: response.isFromExpiredCache
            ),
            items: items
        )

        return (subnets, gates)
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

            return Self.verify(parsed, snapshot: snapshot)
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
