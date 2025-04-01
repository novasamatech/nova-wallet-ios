import Foundation
import UIKit_iOS
import Foundation_iOS
import Keystore_iOS

struct UnifiedAddressPopupViewFactory {
    static func createView(
        newAddress: AccountAddress,
        legacyAddress: AccountAddress
    ) -> UnifiedAddressPopupViewProtocol? {
        let interactor = UnifiedAddressPopupInteractor(settingsManager: SettingsManager.shared)
        let wireframe = UnifiedAddressPopupWireframe()

        let viewModelFactory = UnifiedAddressPopup.ViewModelFactory(
            newAddress: newAddress,
            legacyAddress: legacyAddress,
            applicationConfig: ApplicationConfig.shared
        )
        let localizationManager = LocalizationManager.shared

        let presenter = UnifiedAddressPopupPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            newAddress: newAddress,
            legacyAddress: legacyAddress,
            localizationManager: localizationManager
        )

        let view = UnifiedAddressPopupViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.nova)

        let preferredSize = CGSize(
            width: .zero,
            height: 408
        )

        view.modalTransitioningFactory = factory
        view.modalPresentationStyle = .custom
        view.preferredContentSize = preferredSize

        return view
    }
}
