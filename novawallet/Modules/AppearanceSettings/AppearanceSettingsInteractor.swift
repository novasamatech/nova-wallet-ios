import UIKit

final class AppearanceSettingsInteractor {
    weak var presenter: AppearanceSettingsInteractorOutputProtocol?
}

extension AppearanceSettingsInteractor: AppearanceSettingsInteractorInputProtocol {}
