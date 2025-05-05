import UIKit
import Foundation_iOS
import Keystore_iOS
import NovaCrypto
import SubstrateSdk

struct SettingsViewFactory {
    static func createView(
        with serviceCoordinator: ServiceCoordinatorProtocol
    ) -> SettingsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let walletConnect = serviceCoordinator.dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = SettingsViewModelFactory(
            iconGenerator: NovaIconGenerator(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let operationQueue = OperationManagerFacade.sharedDefaultQueue

        let interactor = SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            walletConnect: walletConnect,
            currencyManager: currencyManager,
            settingsManager: SettingsManager.shared,
            biometryAuth: BiometryAuth(),
            walletNotificationService: serviceCoordinator.walletNotificationService,
            pushNotificationsFacade: PushNotificationsServiceFacade.shared,
            operationQueue: operationQueue
        )

        let wireframe = SettingsWireframe(serviceCoordinator: serviceCoordinator)

        let view = SettingsViewController()

        let presenter = SettingsPresenter(
            viewModelFactory: profileViewModelFactory,
            config: ApplicationConfig.shared,
            interactor: interactor,
            wireframe: wireframe,
            localizationManager: localizationManager,
            logger: Logger.shared
        )

        view.presenter = presenter
        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = localizationManager
        presenter.localizationManager = localizationManager

        return view
    }
}
