import UIKit
import Foundation_iOS

class PayShopBrandsInteractor {
    weak var presenter: PayShopBrandsInteractorOutputProtocol?

    let operationFactory: RaiseOperationFactoryProtocol
    let operationQueue: OperationQueue

    let callStore = CancellableCallStore()

    private var debouncer = Debouncer(delay: 1, queue: .main)
    private var pendingRequest: RaiseBrandsRequestInfo?

    init(
        operationFactory: RaiseOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    deinit {
        debouncer.cancel()
        callStore.cancel()
    }

    private func sendRequest(_ info: RaiseBrandsRequestInfo) {
        let wrapper = operationFactory.createBrandsWrapper(for: info)

        executeCancellable(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            backingCallIn: callStore,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(brandsList):
                self?.presenter?.didReceive(brandList: brandsList, info: info)
            case let .failure(error):
                self?.presenter?.didReceive(error: .brandsFailed(error, info))
            }
        }
    }
}

extension PayShopBrandsInteractor: PayShopBrandsInteractorInputProtocol {
    func requestBrands(for info: RaiseBrandsRequestInfo) {
        callStore.cancel()

        debouncer.debounce { [weak self] in
            self?.sendRequest(info)
        }
    }
}
