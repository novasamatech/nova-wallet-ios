import Foundation
import SoraFoundation
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

        let title = "Page settings"
        view.update(title: title)
        view.update(viewModels: [
            .favorite(favoriteModel(favorite: state.favorite)),
            .desktopModel(.init(title: desktopTitleModel, isOn: state.desktopMode))
        ])
    }

    private func favoriteModel(favorite: Bool) -> TitleIconViewModel {
        let title: String
        let icon: UIImage?

        if favorite {
            title = R.string.localizable.dappRemoveFavoritesTitle(preferredLanguages: selectedLocale.rLanguages)
            icon = R.image.iconUnfavorite()
        } else {
            title = R.string.localizable.dappFavoriteAddTitle(preferredLanguages: selectedLocale.rLanguages)
            icon = R.image.iconFavNotSelected()
        }

        return .init(title: title, icon: icon)
    }

    private var desktopTitleModel: TitleIconViewModel {
        let title: String = "Desktop mode"
        let icon = R.image.iconDesktopMode()

        return .init(title: title, icon: icon)
    }
}

extension DAppSettingsPresenter: DAppSettingsPresenterProtocol {
    func setup() {
        updateView()
    }

    func changeDesktopMode(isOn: Bool) {
        delegate?.desktopModeDidChanged(dAppIdentifier: state.identifier, isOn: isOn)
    }

    func presentFavorite() {
        if state.favorite {
            delegate?.removeFromFavorites(dAppIdentifier: state.identifier)
        } else {
            delegate?.addToFavorites(dAppIdentifier: state.identifier)
        }
    }
}

extension DAppSettingsPresenter: Localizable {
    func applyLocalization() {
        updateView()
    }
}
