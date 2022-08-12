protocol MessageSheetViewProtocol: ControllerBackedProtocol {}

protocol MessageSheetPresenterProtocol: AnyObject {
    func goBack()
}

protocol MessageSheetInteractorInputProtocol: AnyObject {}

protocol MessageSheetInteractorOutputProtocol: AnyObject {}

protocol MessageSheetWireframeProtocol: AnyObject {
    func complete(on view: MessageSheetViewProtocol?)
}
