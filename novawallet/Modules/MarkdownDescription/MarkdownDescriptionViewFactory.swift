import Foundation

struct MarkdownDescriptionViewFactory {
    static func createReferendumFullDetailsView(
        for title: String,
        description: String
    ) -> MarkdownDescriptionViewProtocol {
        createView(from: .init(title: nil, header: title, details: description))
    }

    static func createDelegateDetailsView(
        for name: String,
        description: String
    ) -> MarkdownDescriptionViewProtocol {
        createView(from: .init(title: name, header: nil, details: description))
    }

    static func createView(
        from model: MarkdownDescriptionModel
    ) -> MarkdownDescriptionViewProtocol {
        let wireframe = MarkdownDescriptionWireframe()

        let presenter = MarkdownDescriptionPresenter(
            wireframe: wireframe,
            model: model
        )

        let view = MarkdownDescriptionViewController(presenter: presenter)

        presenter.view = view

        return view
    }
}
