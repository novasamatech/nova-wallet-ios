import Foundation
import Foundation_iOS

final class ConsentBannerUpgradeViewFactory: ConsentBannerUpgradeViewFactoryProtocol {
    static func createView(completion: @escaping () -> Void) -> ConsentBannerUpgradeViewProtocol? {
        let wireframe = ConsentBannerUpgradeWireframe()

        let presenter = ConsentBannerUpgradePresenter(
            wireframe: wireframe,
            consentService: ConsentService(),
            onAcceptance: completion
        )

        let view = ConsentBannerUpgradeViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
