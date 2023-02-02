import Foundation

struct DelegateInfoDetailsViewFactory {
    static func createView(state: DelegateInfoDetailsState) -> DelegateInfoDetailsViewProtocol {
        let presenter = DelegateInfoDetailsPresenter(state: state)

        let view = DelegateInfoDetailsViewController(presenter: presenter)
        presenter.view = view

        return view
    }
}
