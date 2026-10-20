import Foundation
import Operation_iOS

final class SubtensorRecommendationOperationFactory {
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

private extension SubtensorRecommendationOperationFactory {
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
        let generation = makeGeneration(meta, isFromExpiredCache: response.isFromExpiredCache)

        guard generation.stamp.freshness == .fresh else {
            throw BittensorApiError.generationStale
        }

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
            recommended: SubtensorRecommendedValidators(validators: validators),
            gates: clientGates(meta.clientGates)
        )
    }

    static func createCandidatesFetchWrapper(
        for subnet: SubtensorSubnetRef,
        apiOperationFactory: BittensorApiOperationFactoryProtocol,
        logger: LoggerProtocol
    ) -> CompoundOperationWrapper<Candidates> {
        apiOperationFactory.createRankedValidatorsWrapper(netuid: subnet.netuid).mapped { response in
            try makeCandidates(from: response, subnet: subnet, logger: logger)
        }
    }

    func createCandidatesWrapper(for subnet: SubtensorSubnetRef) -> CompoundOperationWrapper<Candidates> {
        let fetch = { [apiOperationFactory, logger] in
            Self.createCandidatesFetchWrapper(for: subnet, apiOperationFactory: apiOperationFactory, logger: logger)
        }

        let firstWrapper = fetch()

        let candidatesWrapper: CompoundOperationWrapper<Candidates> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                do {
                    return try .createWithResult(firstWrapper.targetOperation.extractNoCancellableResultData())
                } catch BittensorApiError.generationStale {
                    return fetch()
                }
            }

        candidatesWrapper.addDependency(wrapper: firstWrapper)

        return candidatesWrapper.insertingHead(operations: firstWrapper.allOperations)
    }

    static func makeRankedSubnets(
        from response: BittensorApiResult<BittensorApi.SubnetRankingCollection>
    ) throws -> SubtensorRankedSubnets {
        try SubtensorRankedSubnets(
            generation: makeGeneration(response.value.meta, isFromExpiredCache: response.isFromExpiredCache),
            items: response.value.items.map { try rankedSubnet($0) }
        )
    }
}

extension SubtensorRecommendationOperationFactory: SubtensorRecommendationOperationFactoryProtocol {
    func createRecommendedValidatorsWrapper(
        for subnet: SubtensorSubnetRef
    ) -> CompoundOperationWrapper<SubtensorRecommendedValidators> {
        let candidatesWrapper = createCandidatesWrapper(for: subnet)
        let chainOperationFactory = chainOperationFactory

        let pair: (SubtensorRecommendedValidator) -> SubtensorHotkeySubnet = {
            SubtensorHotkeySubnet(hotkey: $0.hotkey, netuid: subnet.netuid)
        }

        let snapshotWrapper: CompoundOperationWrapper<SubtensorValidatorChainSnapshot?> =
            OperationCombiningService.compoundWrapper(
                operationManager: OperationManager(operationQueue: operationQueue)
            ) {
                let candidates = try candidatesWrapper.targetOperation.extractNoCancellableResultData()
                let validators = candidates.recommended.validators

                guard !validators.isEmpty else {
                    return nil
                }

                return chainOperationFactory.createChainSnapshotWrapper(
                    for: SubtensorValidatorChainQuery(pairs: validators.map(pair))
                )
            }

        snapshotWrapper.addDependency(wrapper: candidatesWrapper)

        let verifyOperation = ClosureOperation<SubtensorRecommendedValidators> {
            let candidates = try candidatesWrapper.targetOperation.extractNoCancellableResultData()

            guard let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData() else {
                return candidates.recommended
            }

            return SubtensorRecommendedValidators(
                validators: candidates.recommended.validators.filter {
                    SubtensorRecommendationVerifier.passesGates(pair($0), snapshot: snapshot, gates: candidates.gates)
                }
            )
        }

        verifyOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: verifyOperation,
            dependencies: candidatesWrapper.allOperations + snapshotWrapper.allOperations
        )
    }

    func createListVerificationWrapper(
        for subnet: SubtensorSubnetRef,
        listedHotkeys: [AccountId]
    ) -> CompoundOperationWrapper<SubtensorValidatorListVerification> {
        let candidatesWrapper = createCandidatesWrapper(for: subnet)
        let chainOperationFactory = chainOperationFactory

        let candidatesOperation = ClosureOperation<Result<Candidates, Error>> {
            Result { try candidatesWrapper.targetOperation.extractNoCancellableResultData() }
        }

        candidatesOperation.addDependency(candidatesWrapper.targetOperation)

        let pair: (AccountId) -> SubtensorHotkeySubnet = { SubtensorHotkeySubnet(hotkey: $0, netuid: subnet.netuid) }

        let snapshotWrapper: CompoundOperationWrapper<SubtensorValidatorChainSnapshot> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let candidates = try? candidatesOperation.extractNoCancellableResultData().get()
                let recommended = (candidates?.recommended.validators ?? []).map(\.hotkey)
                let query = SubtensorValidatorChainQuery(pairs: (recommended + listedHotkeys).map(pair))

                return chainOperationFactory.createChainSnapshotWrapper(for: query)
            }

        snapshotWrapper.addDependency(operations: [candidatesOperation])

        let verifyOperation = ClosureOperation<SubtensorValidatorListVerification> {
            let candidatesResult = try candidatesOperation.extractNoCancellableResultData()
            let snapshot = try snapshotWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorValidatorListVerification(
                takes: snapshot.takeFractions,
                statuses: listedHotkeys.reduce(into: [:]) { statuses, hotkey in
                    statuses[hotkey] = SubtensorValidatorChainStatus.make(snapshot: snapshot, pair: pair(hotkey))
                },
                recommended: candidatesResult.map { candidates in
                    Set(candidates.recommended.validators.map(\.hotkey).filter { hotkey in
                        SubtensorRecommendationVerifier.passesGates(
                            pair(hotkey),
                            snapshot: snapshot,
                            gates: candidates.gates
                        )
                    })
                }
            )
        }

        verifyOperation.addDependency(snapshotWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: verifyOperation,
            dependencies: candidatesWrapper.allOperations + [candidatesOperation] + snapshotWrapper.allOperations
        )
    }

    func createRankedSubnetsWrapper() -> CompoundOperationWrapper<SubtensorRankedSubnets> {
        apiOperationFactory.createRankedSubnetsWrapper().mapped { try Self.makeRankedSubnets(from: $0) }
    }

    func cachedRankedSubnets() -> HTTPCachePeek<SubtensorRankedSubnets> {
        apiOperationFactory.peekRankedSubnets().map { try Self.makeRankedSubnets(from: $0) }
    }
}
