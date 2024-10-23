import Foundation

final class AssetsSettingsPresenter {
    weak var view: AssetsSettingsViewProtocol?
    let wireframe: AssetsSettingsWireframeProtocol
    let interactor: AssetsSettingsInteractorInputProtocol

    private var hidesZeroBalances: Bool?

    init(
        interactor: AssetsSettingsInteractorInputProtocol,
        wireframe: AssetsSettingsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }

    func changeHideZeroBalances(value: Bool) {
        let canApply = hidesZeroBalances != nil && value != hidesZeroBalances
        hidesZeroBalances = value

        view?.didReceive(viewModel: AssetsSettingsViewModel(hideZeroBalances: value, canApply: canApply))
    }
}

extension AssetsSettingsPresenter: AssetsSettingsPresenterProtocol {
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

extension AssetsSettingsPresenter: AssetsSettingsInteractorOutputProtocol {
    func didReceive(hideZeroBalances: Bool) {
        changeHideZeroBalances(value: hideZeroBalances)
    }

    func didSave() {
        wireframe.close(view: view)
    }
}
