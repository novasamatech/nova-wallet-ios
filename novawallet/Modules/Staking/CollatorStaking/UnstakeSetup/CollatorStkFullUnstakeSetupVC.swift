import Foundation
import SoraFoundation

final class CollatorStkFullUnstakeSetupVC: CollatorStkBaseUnstakeSetupVC<CollatorStkFullUnstakeSetupLayout> {
    var presenter: CollatorStkFullUnstakeSetupPresenterProtocol? {
        basePresenter as? CollatorStkFullUnstakeSetupPresenterProtocol
    }

    init(
        presenter: CollatorStkFullUnstakeSetupPresenterProtocol,
        localizationManager: LocalizationManagerProtocol
    ) {
        super.init(basePresenter: presenter, localizationManager: localizationManager)
    }
}

extension CollatorStkFullUnstakeSetupVC: CollatorStkFullUnstakeSetupViewProtocol {}
