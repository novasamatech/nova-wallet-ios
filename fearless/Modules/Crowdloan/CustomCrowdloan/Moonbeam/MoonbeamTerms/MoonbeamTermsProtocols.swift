import SoraFoundation

protocol MoonbeamTermsViewProtocol: ControllerBackedProtocol {}

protocol MoonbeamTermsPresenterProtocol: AnyObject {
    func setup()
}

protocol MoonbeamTermsInteractorInputProtocol: AnyObject {}

protocol MoonbeamTermsInteractorOutputProtocol: AnyObject {}

protocol MoonbeamTermsWireframeProtocol: AnyObject {}
