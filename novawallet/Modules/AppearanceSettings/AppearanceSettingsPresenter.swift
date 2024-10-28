import Foundation

final class AppearanceSettingsPresenter {
    weak var view: AppearanceSettingsViewProtocol?
    let wireframe: AppearanceSettingsWireframeProtocol
    let interactor: AppearanceSettingsInteractorInputProtocol

    init(
        interactor: AppearanceSettingsInteractorInputProtocol,
        wireframe: AppearanceSettingsWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension AppearanceSettingsPresenter: AppearanceSettingsPresenterProtocol {
    func setup() {}

    func changeTokenIcons(with selectedOption: AppearanceSettingsIconsView.AppearanceIconsOptions) {
        print(selectedOption)
    }
}

extension AppearanceSettingsPresenter: AppearanceSettingsInteractorOutputProtocol {}
