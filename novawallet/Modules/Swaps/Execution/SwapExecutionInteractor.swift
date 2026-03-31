import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let chainRegistry: ChainRegistryProtocol
    let osMediator: OperatingSystemMediating
    let operationQueue: OperationQueue
    let logger: LoggerProtocol

    init(
        assetsExchangeService: AssetsExchangeServiceProtocol,
        chainRegistry: ChainRegistryProtocol,
        osMediator: OperatingSystemMediating,
        operationQueue: OperationQueue,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.assetsExchangeService = assetsExchangeService
        self.chainRegistry = chainRegistry
        self.osMediator = osMediator
        self.operationQueue = operationQueue
        self.logger = logger
    }

    private func performSubmit(
        model: SwapExecutionModel,
        commission: SwapCommissionResult?
    ) {
        let wrapper = assetsExchangeService.submit(
            using: model.fee,
            notifyingIn: .main,
            operationStartClosure: { [weak self] newOperationIndex in
                self?.presenter?.didStartExecution(for: newOperationIndex)
            },
            bundleExtraActions: commission?.builderClosure,
            bundleExtraAmountDeducted: commission?.commissionAmount ?? 0
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.osMediator.enableScreenSleep()

            switch result {
            case let .success(amount):
                self?.presenter?.didCompleteFullExecution(received: amount)
            case let .failure(error):
                self?.presenter?.didFailExecution(with: error)
            }
        }
    }
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using model: SwapExecutionModel) {
        osMediator.disableScreenSleep()

        NovaSwapCommissionClosureFactory.resolveCommission(
            for: model,
            chainRegistry: chainRegistry,
            operationQueue: operationQueue,
            logger: logger
        ) { [weak self] commission in
            self?.performSubmit(model: model, commission: commission)
        }
    }
}
