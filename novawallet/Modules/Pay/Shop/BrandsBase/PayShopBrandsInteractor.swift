import UIKit
import Foundation_iOS

class PayShopBrandsInteractor {
    weak var presenter: RaiseBrandsInteractorOutputProtocol?

    let operationFactory: RaiseOperationFactoryProtocol
    let operationQueue: OperationQueue

    let callStore = CancellableCallStore()

    private var scheduler: SchedulerProtocol?
    private var pendingRequest: RaiseBrandsRequestInfo?

    init(
        operationFactory: RaiseOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.operationFactory = operationFactory
        self.operationQueue = operationQueue
    }

    deinit {
        cancelScheduler()
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

    private func cancelScheduler() {
        scheduler?.cancel()
        scheduler = nil
    }

    private func schedule(request: RaiseBrandsRequestInfo) {
        pendingRequest = request

        scheduler = Scheduler(with: self, callbackQueue: .main)
        scheduler?.notifyAfter(RaiseConstants.debounceInterval)
    }
}

extension PayShopBrandsInteractor: RaiseBrandsInteractorInputProtocol {
    func requestBrands(for info: RaiseBrandsRequestInfo) {
        let hadRequest = callStore.hasCall

        callStore.cancel()
        cancelScheduler()

        if hadRequest {
            schedule(request: info)
        } else {
            sendRequest(info)
        }
    }
}

extension PayShopBrandsInteractor: SchedulerDelegate {
    func didTrigger(scheduler _: SchedulerProtocol) {
        guard let pendingRequest else {
            return
        }

        cancelScheduler()
        sendRequest(pendingRequest)
    }
}
