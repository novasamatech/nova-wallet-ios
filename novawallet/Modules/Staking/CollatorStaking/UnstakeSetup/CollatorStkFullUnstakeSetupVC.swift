import Foundation
import Foundation_iOS

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
