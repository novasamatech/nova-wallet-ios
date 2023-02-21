import Foundation

protocol MarkdownDescriptionViewProtocol: ControllerBackedProtocol {
    func didReceive(model: MarkdownDescriptionModel)
}

protocol MarkdownDescriptionPresenterProtocol: AnyObject {
    func setup()
    func open(url: URL)
}

protocol MarkdownDescriptionWireframeProtocol: WebPresentable {}
