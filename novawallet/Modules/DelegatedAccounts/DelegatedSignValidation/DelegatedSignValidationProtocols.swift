protocol DelegatedSignValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignValidationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignValidationInteractorOutputProtocol: AnyObject {
    func didReceive(
        validationSequenceResult: Result<DelegatedSignValidationSequence, DelegatedSignValidationInteractorError >
    )
}

protocol DelegatedSignValidationWireframeProtocol: AnyObject {
    func proceed(with sequence: DelegatedSignValidationSequence)
}

enum DelegatedSignValidationInteractorError: Error {}
