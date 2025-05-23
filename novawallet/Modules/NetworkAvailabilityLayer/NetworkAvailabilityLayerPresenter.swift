import UIKit
import Foundation_iOS

final class NetworkAvailabilityLayerPresenter {
    var view: ApplicationStatusPresentable!

    var unavailbleStyle: ApplicationStatusStyle {
        ApplicationStatusStyle(
            backgroundColor: R.color.colorIconAccent()!,
            titleColor: UIColor.white,
            titleFont: UIFont.h6Title
        )
    }

    var availableStyle: ApplicationStatusStyle {
        ApplicationStatusStyle(
            backgroundColor: R.color.colorTextPositive()!,
            titleColor: UIColor.white,
            titleFont: UIFont.h6Title
        )
    }
}

extension NetworkAvailabilityLayerPresenter: NetworkAvailabilityLayerInteractorOutputProtocol {
    func didDecideUnreachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.presentStatus(
            title: R.string.localizable
                .networkStatusConnecting(preferredLanguages: languages),
            style: unavailbleStyle,
            animated: true
        )
    }

    func didDecideReachableStatusPresentation() {
        let languages = localizationManager?.preferredLocalizations
        view.dismissStatus(
            title: R.string.localizable
                .networkStatusConnected(preferredLanguages: languages),
            style: availableStyle,
            animated: true
        )
    }
}

extension NetworkAvailabilityLayerPresenter: Localizable {
    func applyLocalization() {}
}
