import UIKit

final class SwapExecutionInteractor {
    weak var presenter: SwapExecutionInteractorOutputProtocol?

    let assetsExchangeService: AssetsExchangeServiceProtocol
    let operationQueue: OperationQueue

    init(
        assetsExchangeService: AssetsExchangeServiceProtocol,
        operationQueue: OperationQueue
    ) {
        self.assetsExchangeService = assetsExchangeService
        self.operationQueue = operationQueue
    }
}

extension SwapExecutionInteractor: SwapExecutionInteractorInputProtocol {
    func submit(using estimation: AssetExchangeFee) {
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
            switch result {
            case let .success(amount):
                self?.presenter?.didCompleteFullExecution(received: amount)
            case let .failure(error):
                self?.presenter?.didFailExecution(with: error)
            }
        }
    }
}
