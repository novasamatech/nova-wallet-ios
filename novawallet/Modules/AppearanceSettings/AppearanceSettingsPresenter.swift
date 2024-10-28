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

// MARK: AppearanceSettingsPresenterProtocol

extension AppearanceSettingsPresenter: AppearanceSettingsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func changeTokenIcons(with selectedOption: AppearanceSettingsIconsView.AppearanceOptions) {
        interactor.selectTokenIconsOption(.init(from: selectedOption))
    }
}

// MARK: AppearanceSettingsInteractorOutputProtocol

extension AppearanceSettingsPresenter: AppearanceSettingsInteractorOutputProtocol {
    func didReceiveAppearance(iconsOption: AppearanceIconsOptions) {
        let model = AppearanceSettingsIconsView.Model(
            selectedOption: .init(from: iconsOption)
        )

        view?.update(with: model)
    }
}
