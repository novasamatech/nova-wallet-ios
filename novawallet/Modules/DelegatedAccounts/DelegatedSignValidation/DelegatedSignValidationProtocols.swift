protocol DelegatedSignValidationPresenterProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignValidationInteractorInputProtocol: AnyObject {
    func setup()
}

protocol DelegatedSignValidationInteractorOutputProtocol: AnyObject {
    func didReceive(
        validationSequenceResult: Result<DelegatedSignValidationSequence, Error>
    )
}

protocol DelegatedSignValidationWireframeProtocol: AnyObject {
    func proceed(from view: ControllerBackedProtocol, with sequence: DelegatedSignValidationSequence)
    func completeWithError()
}

enum DelegatedSignValidationInteractorError: Error {
    case missingDelegationPath
}
