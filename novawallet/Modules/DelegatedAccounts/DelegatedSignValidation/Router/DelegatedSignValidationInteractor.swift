import UIKit
import SubstrateSdk

final class DelegatedSignValidationInteractor {
    weak var presenter: DelegatedSignValidationInteractorOutputProtocol?

    let call: JSON
    let resolution: ExtrinsicSenderResolution.ResolvedDelegate
    let validationSequenceFactory: DSValidationSequenceFactoryProtocol
    let operationQueue: OperationQueue

    init(
        call: JSON,
        resolution: ExtrinsicSenderResolution.ResolvedDelegate,
        validationSequenceFactory: DSValidationSequenceFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.call = call
        self.resolution = resolution
        self.validationSequenceFactory = validationSequenceFactory
        self.operationQueue = operationQueue
    }
}

extension DelegatedSignValidationInteractor: DelegatedSignValidationInteractorInputProtocol {
    func setup() {
        guard let path = resolution.paths[call] else {
            presenter?.didReceive(
                validationSequenceResult: .failure(
                    DelegatedSignValidationInteractorError.missingDelegationPath
                )
            )

            return
        }

        guard let delegateAccount = resolution.delegateAccount else {
            presenter?.didReceive(
                validationSequenceResult: .failure(
                    DelegatedSignValidationInteractorError.missingDelegateAccount
                )
            )

            return
        }

        let wrapper = validationSequenceFactory.createWrapper(
            for: call,
            extrinsicSender: delegateAccount,
            unwrappedCallOrigin: resolution.delegatedAccount,
            resolvedPath: path,
            chainId: resolution.chain.chainId
        )

        execute(
            wrapper: wrapper,
            inOperationQueue: operationQueue,
            runningCallbackIn: .main
        ) { [weak self] result in
            self?.presenter?.didReceive(validationSequenceResult: result)
        }
    }
}
