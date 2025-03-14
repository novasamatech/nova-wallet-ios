import Foundation

struct UnifiedAddressPopupViewFactory {
    static func createView() -> UnifiedAddressPopupViewProtocol? {
        let interactor = UnifiedAddressPopupInteractor()
        let wireframe = UnifiedAddressPopupWireframe()

        let presenter = UnifiedAddressPopupPresenter(interactor: interactor, wireframe: wireframe)

        let view = UnifiedAddressPopupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}