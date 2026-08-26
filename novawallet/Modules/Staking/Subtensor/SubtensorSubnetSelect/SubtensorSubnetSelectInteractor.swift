import Foundation
import Operation_iOS
import SubstrateSdk

final class SubtensorSubnetSelectInteractor: RuntimeConstantFetching {
    weak var presenter: SubnetSelectInteractorOutputProtocol?

    let subnetsService: SubtensorSubnetsServiceProtocol
    let runtimeProvider: RuntimeCodingServiceProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        subnetsService: SubtensorSubnetsServiceProtocol,
        runtimeProvider: RuntimeCodingServiceProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol
    ) {
        self.subnetsService = subnetsService
        self.runtimeProvider = runtimeProvider
        self.operationQueue = operationQueue
        self.logger = logger
    }
}

private extension SubtensorSubnetSelectInteractor {
    func provideSubnetsInfo() {
        subnetsService.fetchSubnetsInfo(runningCompletionIn: .main) { [weak self] result in
            switch result {
            case let .success(info):
                self?.presenter?.didReceiveSubnetsInfo(info)
            case let .failure(error):
                self?.presenter?.didReceiveError(error)
            }
        }
    }

    func provideDefaultTake() {
        fetchConstant(
            for: SubtensorStakingPallet.initialDefaultDelegateTakePath,
            runtimeCodingService: runtimeProvider,
            operationQueue: operationQueue
        ) { [weak self] (result: Result<UInt16, Error>) in
            switch result {
            case let .success(take):
                self?.presenter?.didReceiveDefaultTake(take)
            case let .failure(error):
                self?.logger.error("Default take fetch failed: \(error)")
            }
        }
    }
}

extension SubtensorSubnetSelectInteractor: SubnetSelectInteractorInputProtocol {
    func setup() {
        provideDefaultTake()
        provideSubnetsInfo()
    }

    func refresh() {
        provideSubnetsInfo()
    }
}
