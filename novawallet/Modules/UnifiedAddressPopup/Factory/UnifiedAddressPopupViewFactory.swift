import Foundation
import SoraUI
import SoraFoundation
import SoraKeystore

struct UnifiedAddressPopupViewFactory {
    static func createView(
        newAddress: AccountAddress,
        legacyAddress: AccountAddress
    ) -> UnifiedAddressPopupViewProtocol? {
        let interactor = UnifiedAddressPopupInteractor(settingsManager: SettingsManager.shared)
        let wireframe = UnifiedAddressPopupWireframe()

        let viewModelFactory = UnifiedAddressPopup.ViewModelFactory(
            newAddress: newAddress,
            legacyAddress: legacyAddress
        )
        let localizationManager = LocalizationManager.shared

        let presenter = UnifiedAddressPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager
        )

        let view = UnifiedAddressPopupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom
        view.preferredContentSize = CGSize(width: .zero, height: 442)

        return view
    }
}
