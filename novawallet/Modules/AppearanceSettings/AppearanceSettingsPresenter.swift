import Foundation

final class AppearanceSettingsPresenter {
    weak var view: AppearanceSettingsViewProtocol?
    let wireframe: AppearanceSettingsWireframeProtocol
    let appearanceFacade: AppearanceFacadeProtocol

    init(
        appearanceFacade: AppearanceFacadeProtocol,
        wireframe: AppearanceSettingsWireframeProtocol
    ) {
        self.appearanceFacade = appearanceFacade
        self.wireframe = wireframe
    }
}

// MARK: AppearanceSettingsPresenterProtocol

extension AppearanceSettingsPresenter: AppearanceSettingsPresenterProtocol {
    func setup() {
        let selectedIconsAppearance = appearanceFacade.selectedIconAppearance
        let model = AppearanceSettingsIconsView.Model(
            selectedOption: .init(from: selectedIconsAppearance)
        )
        view?.update(with: model)
    }

    func changeTokenIcons(with selectedOption: AppearanceSettingsIconsView.AppearanceOptions) {
        appearanceFacade.selectedIconAppearance = .init(from: selectedOption)

        wireframe.presentAppearanceChanged(from: view)
    }
}
