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
    struct Candidates {
        let recommended: SubtensorRecommendedValidators
        let gates: SubtensorClientGates
    }

    static func makeCandidates(
        from response: BittensorApiResult<BittensorApi.RankedValidatorCollection>,
        subnet: SubtensorSubnetRef,
        logger: LoggerProtocol
    ) throws -> Candidates {
        let meta = response.value.meta
        let reader = DecimalReader(
            route: "/recommendations/subnets/\(subnet.netuid)/validators",
            requestId: response.requestId
        )

        let generation = makeGeneration(meta, isFromExpiredCache: response.isFromExpiredCache)
        let isSameSubnet = subnet.registeredAt <= generation.sourceBlockNumber

        let validators = response.value.items.compactMap { item -> SubtensorRecommendedValidator? in
            guard
                isSameSubnet,
                item.netuid == subnet.netuid,
                item.eligible,
                item.recommendationClass != .aboveThreshold else {
                return nil
            }

            guard let hotkey = try? item.hotkey.toAccountId(
                using: .substrate(SubstrateConstants.genericAddressPrefix)
            ) else {
                logger.warning("Skipped a recommended validator of netuid \(subnet.netuid) with an undecodable hotkey")
                return nil
            }

            return SubtensorRecommendedValidator(hotkey: hotkey, name: item.validatorName)
        }

        return try Candidates(
            recommended: SubtensorRecommendedValidators(generation: generation, validators: validators),
            gates: reader.clientGates(meta.clientGates)
        )
    }

    static func makeRankedSubnets(
        from response: BittensorApiResult<BittensorApi.SubnetRankingCollection>
    ) throws -> SubtensorRankedSubnets {
        let reader = DecimalReader(route: "/recommendations/subnets", requestId: response.requestId)

        let items = try response.value.items.enumerated().map { index, item in
            try reader.rankedSubnet(item, "items[\(index)]")
        }

        return SubtensorRankedSubnets(
            generation: makeGeneration(response.value.meta, isFromExpiredCache: response.isFromExpiredCache),
            items: items
        )
    }
}

extension SubtensorRecommendationService: SubtensorRecommendationServiceProtocol {
    func createRecommendedValidatorsWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorRecommendedValidators> {
        let responseWrapper = apiOperationFactory.createRankedValidatorsWrapper(netuid: subnet.netuid)
        let chainOperationFactory = chainOperationFactory
        let logger = logger

        let candidatesOperation = ClosureOperation<Candidates> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeCandidates(from: response, subnet: subnet, logger: logger)
        }

        candidatesOperation.addDependency(responseWrapper.targetOperation)

        let pair: (SubtensorRecommendedValidator) -> SubtensorHotkeySubnet = {
            SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: subnet.netuid)
        }

        let snapshotWrapper: CompoundOperationWrapper<SubtensorValidatorChainSnapshot?> =
            OperationCombiningService.compoundWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let validators = try candidatesOperation.extractNoCancellableResultData().recommended.validators

                guard !validators.isEmpty else {
                    return nil
                }

                return chainOperationFactory.createChainSnapshotWrapper(
                    for: SubtensorRecommendationVerifier.chainQuery(for: validators.map(pair))
                )
            }

        snapshotWrapper.addDependency(operations: [candidatesOperation])

        let verifyOperation = ClosureOperation<SubtensorRecommendedValidators> {
            let candidates = try candidatesOperation.extractNoCancellableResultData()

            guard let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData() else {
                return candidates.recommended
            }

            return SubtensorRecommendedValidators(
                generation: candidates.recommended.generation,
                validators: candidates.recommended.validators.filter {
                    SubtensorRecommendationVerifier.passesGates(pair($0), snapshot: snapshot, gates: candidates.gates)
                }
            )
        }

        verifyOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: verifyOperation,
            dependencies: responseWrapper.allOperations + [candidatesOperation] + snapshotWrapper.allOperations
        )
    }

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets> {
        let responseWrapper = apiOperationFactory.createRankedSubnetsWrapper()

        let mappingOperation = ClosureOperation<SubtensorRankedSubnets> {
            let response = try responseWrapper.targetOperation.extractNoCancellableResultData()

            return try Self.makeRankedSubnets(from: response)
        }

        mappingOperation.addDependency(responseWrapper.targetOperation)

        return responseWrapper.insertingTail(operation: mappingOperation)
    }

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets> {
        apiOperationFactory.peekRankedSubnets().map { try Self.makeRankedSubnets(from: $0) }
    }
}
