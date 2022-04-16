import Foundation

struct DAppAuthSettingsViewFactory {
    static func createView() -> DAppAuthSettingsViewProtocol? {
        let interactor = DAppAuthSettingsInteractor()
        let wireframe = DAppAuthSettingsWireframe()

        let presenter = DAppAuthSettingsPresenter(interactor: interactor, wireframe: wireframe)

        let view = DAppAuthSettingsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}