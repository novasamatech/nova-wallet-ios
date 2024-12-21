import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let osMediator: OperatingSystemMediating
    let operationQueue: OperationQueue

    init(
        assetsExchangeService: AssetsExchangeServiceProtocol,
        osMediator: OperatingSystemMediating,
        operationQueue: OperationQueue
    ) {
        self.assetsExchangeService = assetsExchangeService
        self.osMediator = osMediator
        self.operationQueue = operationQueue
    }
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee) {
        osMediator.disableScreenSleep()

        let wrapper = assetsExchangeService.submit(
            using: estimation,
            notifyingIn: .main
        ) { [weak self] newOperationIndex in
            self?.presenter?.didStartExecution(for: newOperationIndex)
        }

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
