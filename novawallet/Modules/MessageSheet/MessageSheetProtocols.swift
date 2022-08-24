import Foundation

protocol MessageSheetViewProtocol: ControllerBackedProtocol {}

protocol MessageSheetGraphicsProtocol {
    associatedtype GraphicsViewModel

    func bind(messageSheetGraphics: GraphicsViewModel?, locale: Locale)
}

protocol MessageSheetPresenterProtocol: AnyObject {
    func goBack()
}

protocol MessageSheetInteractorInputProtocol: AnyObject {}

protocol MessageSheetInteractorOutputProtocol: AnyObject {}

protocol MessageSheetWireframeProtocol: AnyObject {
    func complete(on view: MessageSheetViewProtocol?)
}

typealias MessageSheetCallback = () -> Void
