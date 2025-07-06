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
        guard let path = resolution.path else {
            presenter?.didReceive(
                validationSequenceResult: .failure(
                    DelegatedSignValidationInteractorError.missingDelegationPath
                )
            )

            return
        }

        let wrapper = validationSequenceFactory.createWrapper(
            for: call,
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
