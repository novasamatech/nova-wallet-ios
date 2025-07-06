import Foundation

final class DelegatedSignValidationPresenter {
    let view: ControllerBackedProtocol
    let wireframe: DelegatedSignValidationWireframeProtocol
    let interactor: DelegatedSignValidationInteractorInputProtocol
    let logger: LoggerProtocol

    init(
        view: ControllerBackedProtocol,
        interactor: DelegatedSignValidationInteractorInputProtocol,
        wireframe: DelegatedSignValidationWireframeProtocol,
        logger: LoggerProtocol
    ) {
        self.view = view
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
    }
}

extension DelegatedSignValidationPresenter: DelegatedSignValidationPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension DelegatedSignValidationPresenter: DelegatedSignValidationInteractorOutputProtocol {
    func didReceive(
        validationSequenceResult: Result<DelegatedSignValidationSequence, Error>
    ) {
        switch validationSequenceResult {
        case let .success(sequence):
            wireframe.proceed(from: view, with: sequence)
        case let .failure(error):
            logger.error("Unexpected error: \(error)")

            wireframe.completeWithError()
        }
    }
}
