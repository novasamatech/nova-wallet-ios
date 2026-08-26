import BigInt
import Foundation
import Operation_iOS

protocol SubtensorRootAprInputsServiceProtocol: AnyObject {
    func fetchInputs(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorRootAprInputs, Error>) -> Void
    )
}

/// session cache for the scalar read the engine adds on top of the subnets cache
final class SubtensorRootAprInputsService: SubtensorSessionCachingService<SubtensorRootAprInputs> {
    let operationFactory: SubtensorRootAprOperationFactoryProtocol

    init(
        operationFactory: SubtensorRootAprOperationFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.operationFactory = operationFactory

        super.init(operationQueue: operationQueue, logger: logger)
    }

    override func createFetchWrapper() -> CompoundOperationWrapper<SubtensorRootAprInputs> {
        operationFactory.createInputsWrapper()
    }
}

extension SubtensorRootAprInputsService: SubtensorRootAprInputsServiceProtocol {
    func fetchInputs(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorRootAprInputs, Error>) -> Void
    ) {
        fetch(runningCompletionIn: queue, completion: completion)
    }
}

protocol SubtensorRewardCalculatorServiceProtocol: AnyObject {
    func fetchEngine(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorRewardCalculatorEngineProtocol, Error>) -> Void
    )
}

/// Assembles the root APY engine (spec §6.2) from the two session caches it depends on.
///
/// The join happens at callback level rather than inside a `CompoundOperationWrapper` on purpose:
/// nesting the subnets fetch under an operation would put a state-call wrapper behind whatever
/// width the shared queue happens to have.
final class SubtensorRewardCalculatorService {
    let subnetsService: SubtensorSubnetsServiceProtocol
    let inputsService: SubtensorRootAprInputsServiceProtocol
    let logger: LoggerProtocol

    private let syncQueue = DispatchQueue(
        label: "com.novawallet.subtensor.rewcalculator.\(UUID().uuidString)",
        qos: .userInitiated
    )

    init(
        subnetsService: SubtensorSubnetsServiceProtocol,
        inputsService: SubtensorRootAprInputsServiceProtocol,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.subnetsService = subnetsService
        self.inputsService = inputsService
        self.logger = logger
    }
}

extension SubtensorRewardCalculatorService {
    static func makeParams(
        subnetsInfo: SubtensorSubnetsInfo,
        inputs: SubtensorRootAprInputs
    ) -> SubtensorRootAprCalculator.Params? {
        guard
            let root = subnetsInfo.subnets.first(
                where: { $0.netuid == SubtensorStakingPallet.rootNetuid }
            ) else {
            return nil
        }

        // OwnerCutEnabled is a per-subnet map with a `true` default; reading it would cost one key
        // per subnet on every refresh, so a subnet that disables the cut is understated by the cut
        var subnets: [SubtensorRootAprCalculator.Subnet] = []

        for dynamicInfo in subnetsInfo.subnets {
            guard let price = subnetsInfo.prices[dynamicInfo.netuid] else {
                // valuing an emitting subnet at zero would silently understate the rate, so an
                // incomplete price map yields no number at all (spec §6.2)
                guard dynamicInfo.alphaOutEmission == 0 else {
                    return nil
                }

                continue
            }

            subnets.append(
                SubtensorRootAprCalculator.Subnet(
                    netuid: dynamicInfo.netuid,
                    alphaOutEmission: dynamicInfo.alphaOutEmission,
                    alphaIssuance: dynamicInfo.alphaIn + dynamicInfo.alphaOut,
                    price: price,
                    movingPriceBits: dynamicInfo.movingPriceBits ?? 0,
                    ownerCutEnabled: true
                )
            )
        }

        return SubtensorRootAprCalculator.Params(
            taoWeight: inputs.taoWeight,
            rootTao: root.taoIn,
            rootStake: root.alphaOut,
            ownerCut: subnetsInfo.ownerCut,
            subnets: subnets
        )
    }
}

private extension SubtensorRewardCalculatorService {
    final class Join {
        var subnetsResult: Result<SubtensorSubnetsInfo, Error>?
        var inputsResult: Result<SubtensorRootAprInputs, Error>?
        var isDelivered = false

        var isComplete: Bool {
            subnetsResult != nil && inputsResult != nil
        }
    }

    func deliverIfNeeded(
        join: Join,
        queue: DispatchQueue,
        completion: @escaping (Result<SubtensorRewardCalculatorEngineProtocol, Error>) -> Void
    ) {
        guard join.isComplete, !join.isDelivered else {
            return
        }

        join.isDelivered = true

        let result: Result<SubtensorRewardCalculatorEngineProtocol, Error>

        switch (join.subnetsResult, join.inputsResult) {
        case let (.failure(error), _), let (_, .failure(error)):
            result = .failure(error)
        case let (.success(subnetsInfo), .success(inputs)):
            if let params = Self.makeParams(subnetsInfo: subnetsInfo, inputs: inputs) {
                result = .success(SubtensorRewardCalculatorEngine(params: params))
            } else {
                result = .failure(SubtensorRewardCalculatorError.rootSubnetMissing)
            }
        default:
            result = .failure(SubtensorRewardCalculatorError.rootSubnetMissing)
        }

        if case let .failure(error) = result {
            logger.error("Root APY engine unavailable: \(error)")
        }

        queue.async {
            completion(result)
        }
    }
}

enum SubtensorRewardCalculatorError: Error {
    case rootSubnetMissing
}

extension SubtensorRewardCalculatorService: SubtensorRewardCalculatorServiceProtocol {
    func fetchEngine(
        runningCompletionIn queue: DispatchQueue,
        completion: @escaping (Result<SubtensorRewardCalculatorEngineProtocol, Error>) -> Void
    ) {
        let join = Join()

        subnetsService.fetchSubnetsInfo(runningCompletionIn: syncQueue) { [weak self] result in
            join.subnetsResult = result

            self?.deliverIfNeeded(join: join, queue: queue, completion: completion)
        }

        inputsService.fetchInputs(runningCompletionIn: syncQueue) { [weak self] result in
            join.inputsResult = result

            self?.deliverIfNeeded(join: join, queue: queue, completion: completion)
        }
    }
}
