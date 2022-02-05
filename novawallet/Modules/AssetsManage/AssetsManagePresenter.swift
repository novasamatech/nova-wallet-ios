import Foundation

final class AssetsManagePresenter {
    weak var view: AssetsManageViewProtocol?
    let wireframe: AssetsManageWireframeProtocol
    let interactor: AssetsManageInteractorInputProtocol

    private var hidesZeroBalances: Bool?

    init(
        interactor: AssetsManageInteractorInputProtocol,
        wireframe: AssetsManageWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func changeHideZeroBalances(value: Bool) {
        let canApply = hidesZeroBalances != nil && value != hidesZeroBalances
        hidesZeroBalances = value

        view?.didReceive(viewModel: AssetsManageViewModel(hideZeroBalances: value, canApply: canApply))
    }
}

extension AssetsManagePresenter: AssetsManagePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func setHideZeroBalances(value: Bool) {
        changeHideZeroBalances(value: value)
    }

    func apply() {
        if let value = hidesZeroBalances {
            interactor.save(hideZeroBalances: value)
        }
    }
}

extension AssetsManagePresenter: AssetsManageInteractorOutputProtocol {
    func didReceive(hideZeroBalances: Bool) {
        changeHideZeroBalances(value: hideZeroBalances)
    }

    func didSave() {
        wireframe.close(view: view)
    }
}
