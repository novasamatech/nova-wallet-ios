import Foundation

final class MarkdownDescriptionPresenter {
    weak var view: MarkdownDescriptionViewProtocol?
    let wireframe: MarkdownDescriptionWireframeProtocol

    let model: MarkdownDescriptionModel

    init(
        wireframe: MarkdownDescriptionWireframeProtocol,
        model: MarkdownDescriptionModel
    ) {
        self.wireframe = wireframe
        self.model = model
    }
}

extension MarkdownDescriptionPresenter: MarkdownDescriptionPresenterProtocol {
    func setup() {
        view?.didReceive(model: model)
    }

    func open(url: URL) {
        guard let view = view else {
            return
        }

        wireframe.showWeb(url: url, from: view, style: .modal)
    }
}
