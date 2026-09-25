import Foundation
import Operation_iOS

final class SubtensorDiscoveryService {
    static let rootSubnet = SubtensorSubnetRef(netuid: SubtensorStakingPallet.rootNetuid, registeredAt: 0)

    let yieldService: SubtensorYieldServiceProtocol
    let directoryService: SubtensorValidatorDirectoryServiceProtocol
    let recommendationService: SubtensorRecommendationServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        yieldService: SubtensorYieldServiceProtocol,
        directoryService: SubtensorValidatorDirectoryServiceProtocol,
        recommendationService: SubtensorRecommendationServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.yieldService = yieldService
        self.directoryService = directoryService
        self.recommendationService = recommendationService
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorDiscoveryService {
    enum Recommendations {
        case verified(SubtensorVerifiedRecommendations)
        case routeUnavailable
    }

    struct OfferInputs {
        let steadyTake: Decimal?
        let availableKinds: Set<SubtensorStrategyKind>
    }

    static func recommendationClass(for kind: SubtensorStrategyKind) -> SubtensorRecommendationClass {
        switch kind {
        case .steady:
            return .stable
        case .balanced:
            return .balanced
        case .higherUpside:
            return .higherUpside
        }
    }

    static func isRouteUnavailable(_ error: Error) -> Bool {
        switch error as? BittensorApiError {
        case .routeNotPublished, .datasetUnavailable:
            return true
        default:
            return false
        }
    }

    static func take(of candidate: SubtensorPickCandidate) -> Decimal? {
        switch candidate {
        case let .pair(pair):
            return pair.verification.take
        case let .fallbackRoot(item):
            return item.take
        }
    }

    static func candidates(
        for kind: SubtensorStrategyKind,
        in recommendations: SubtensorVerifiedRecommendations
    ) -> SubtensorPickCandidates {
        let pairs = recommendations.classes[recommendationClass(for: kind)] ?? []

        return SubtensorPickCandidates(
            kind: kind,
            candidates: pairs.map { .pair($0) },
            generationId: recommendations.generation.id
        )
    }

    static func offerInputs(
        recommendations: Recommendations,
        steady: SubtensorPickCandidates
    ) -> OfferInputs {
        var availableKinds: Set<SubtensorStrategyKind> = steady.candidates.isEmpty ? [] : [.steady]

        if case let .verified(verified) = recommendations {
            for kind in [SubtensorStrategyKind.balanced, .higherUpside]
                where !(verified.classes[recommendationClass(for: kind)] ?? []).isEmpty {
                availableKinds.insert(kind)
            }
        }

        return OfferInputs(
            steadyTake: steady.candidates.first.flatMap { take(of: $0) },
            availableKinds: availableKinds
        )
    }

    func createRecommendationsWrapper() -> CompoundOperationWrapper<Recommendations> {
        let verifiedWrapper = recommendationService.createVerifiedRecommendationsWrapper()
        let logger = logger

        let recommendationsOperation = ClosureOperation<Recommendations> {
            do {
                return try .verified(verifiedWrapper.targetOperation.extractNoCancellableResultData())
            } catch {
                guard Self.isRouteUnavailable(error) else {
                    throw error
                }

                logger.warning("Subtensor recommendation pairs unavailable: \(error)")

                return .routeUnavailable
            }
        }

        recommendationsOperation.addDependency(verifiedWrapper.targetOperation)

        return verifiedWrapper.insertingTail(operation: recommendationsOperation)
    }

    static func createFallbackRootWrapper(
        using directoryService: SubtensorValidatorDirectoryServiceProtocol
    ) -> CompoundOperationWrapper<SubtensorPickCandidates> {
        let preferredWrapper = directoryService.createPreferredValidatorWrapper(for: rootSubnet)

        let candidatesOperation = ClosureOperation<SubtensorPickCandidates> {
            let preferred = try preferredWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorPickCandidates(
                kind: .steady,
                candidates: preferred.map { [.fallbackRoot($0)] } ?? [],
                generationId: nil
            )
        }

        candidatesOperation.addDependency(preferredWrapper.targetOperation)

        return preferredWrapper.insertingTail(operation: candidatesOperation)
    }

    func createCandidatesWrapper(
        for kind: SubtensorStrategyKind,
        dependingOn recommendationsOperation: BaseOperation<Recommendations>
    ) -> CompoundOperationWrapper<SubtensorPickCandidates> {
        let directoryService = directoryService

        let candidatesWrapper: CompoundOperationWrapper<SubtensorPickCandidates> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                switch try recommendationsOperation.extractNoCancellableResultData() {
                case let .verified(recommendations):
                    return .createWithResult(Self.candidates(for: kind, in: recommendations))
                case .routeUnavailable where kind == .steady:
                    return Self.createFallbackRootWrapper(using: directoryService)
                case .routeUnavailable:
                    return .createWithResult(SubtensorPickCandidates(kind: kind, candidates: [], generationId: nil))
                }
            }

        candidatesWrapper.addDependency(operations: [recommendationsOperation])

        return candidatesWrapper
    }
}

extension SubtensorDiscoveryService: SubtensorDiscoveryServiceProtocol {
    func createStrategyOffersWrapper() -> CompoundOperationWrapper<[SubtensorStrategyOffer]> {
        let recommendationsWrapper = createRecommendationsWrapper()

        let steadyWrapper = createCandidatesWrapper(
            for: .steady,
            dependingOn: recommendationsWrapper.targetOperation
        )

        let logger = logger

        let inputsOperation = ClosureOperation<OfferInputs> {
            do {
                return try Self.offerInputs(
                    recommendations: recommendationsWrapper.targetOperation.extractNoCancellableResultData(),
                    steady: steadyWrapper.targetOperation.extractNoCancellableResultData()
                )
            } catch {
                logger.warning("Subtensor strategy candidates unavailable, offering the gross root rate: \(error)")

                return OfferInputs(steadyTake: nil, availableKinds: [])
            }
        }

        inputsOperation.addDependency(steadyWrapper.targetOperation)

        let yieldService = yieldService

        let rateWrapper: CompoundOperationWrapper<SubtensorRate?> =
            OperationCombiningService.compoundNonOptionalWrapper(operationQueue: operationQueue) {
                let take = try inputsOperation.extractNoCancellableResultData().steadyTake

                return yieldService.createRootNetworkRateWrapper(take: take)
            }

        rateWrapper.addDependency(operations: [inputsOperation])

        let offersOperation = ClosureOperation<[SubtensorStrategyOffer]> {
            let inputs = try inputsOperation.extractNoCancellableResultData()
            let steadyRate = try rateWrapper.targetOperation.extractNoCancellableResultData()

            return SubtensorStrategyKind.allCases.map { kind in
                SubtensorStrategyOffer(
                    kind: kind,
                    rootNetworkRate: kind == .steady ? steadyRate : nil,
                    isAvailable: inputs.availableKinds.contains(kind)
                )
            }
        }

        offersOperation.addDependency(rateWrapper.targetOperation)

        return CompoundOperationWrapper(
            targetOperation: offersOperation,
            dependencies: recommendationsWrapper.allOperations + steadyWrapper.allOperations + [inputsOperation] +
                rateWrapper.allOperations
        )
    }

    func createPickCandidatesWrapper(
        for kind: SubtensorStrategyKind
    ) -> CompoundOperationWrapper<SubtensorPickCandidates> {
        let recommendationsWrapper = createRecommendationsWrapper()

        let candidatesWrapper = createCandidatesWrapper(
            for: kind,
            dependingOn: recommendationsWrapper.targetOperation
        )

        return candidatesWrapper.insertingHead(operations: recommendationsWrapper.allOperations)
    }
}
