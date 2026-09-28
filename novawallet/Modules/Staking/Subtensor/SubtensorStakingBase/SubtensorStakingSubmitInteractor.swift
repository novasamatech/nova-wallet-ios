import Operation_iOS
import SubstrateSdk
import UIKit

class SubtensorStakingSubmitInteractor: SubtensorStakingBaseInteractor {
    var submitPresenter: SubtensorStakingSubmitInteractorOutputProtocol? {
        basePresenter as? SubtensorStakingSubmitInteractorOutputProtocol
    }
}

extension SubtensorStakingSubmitInteractor: SubtensorStakingSubmitInteractorInputProtocol {
    func submit(operation: SubtensorStakingOperation) {
        let wrapper = operationService.createSubmitWrapper(for: operation)

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            switch result {
            case let .success(outcome):
                self?.submitPresenter?.didReceiveSubmissionResult(.success(outcome))
            case let .failure(error):
                let failure = (error as? SubtensorStakingSubmissionFailure) ?? SubtensorStakingSubmissionFailure(
                    stage: .unconfirmed(extrinsicHash: nil),
                    error: error
                )

                self?.submitPresenter?.didReceiveSubmissionResult(.failure(failure))
            }
        }
    }
}
