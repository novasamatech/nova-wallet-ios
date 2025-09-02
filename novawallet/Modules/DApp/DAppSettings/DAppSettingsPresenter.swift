import Foundation
import Foundation_iOS
import UIKit

final class DAppSettingsPresenter {
    weak var view: DAppSettingsViewProtocol?
    weak var delegate: DAppSettingsDelegate?
    let state: DAppSettingsInput

    init(
        state: DAppSettingsInput,
        delegate: DAppSettingsDelegate,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.delegate = delegate
        self.state = state
        self.localizationManager = localizationManager
    }

    private func updateView() {
        guard let view = view else {
            return
        }

        let title = R.string.localizable.dappSettingsTitle(preferredLanguages: selectedLocale.rLanguages)
        view.update(title: title)
        view.update(viewModels: [
            .desktopModel(.init(title: desktopTitleModel, isOn: state.desktopMode))
        ])
    }

    private var desktopTitleModel: TitleIconViewModel {
        let title = R.string.localizable.dappSettingsModeDesktop(preferredLanguages: selectedLocale.rLanguages)
        let icon = R.image.iconDesktopMode()

        return .init(title: title, icon: icon)
    }
}

extension DAppSettingsPresenter: DAppSettingsPresenterProtocol {
    func setup() {
        updateView()
    }

    func changeDesktopMode(isOn: Bool) {
        delegate?.desktopModeDidChanged(page: state.page, isOn: isOn)
    }
}

extension DAppSettingsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
