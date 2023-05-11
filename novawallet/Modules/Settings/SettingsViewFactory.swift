import UIKit
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SubstrateSdk

struct SettingsViewFactory {
    static func createView(with dappMediator: DAppInteractionMediating) -> SettingsViewProtocol? {
        guard
            let currencyManager = CurrencyManager.shared,
            let walletConnect = dappMediator.children.first(
                where: { $0 is WalletConnectDelegateInputProtocol }
            ) as? WalletConnectDelegateInputProtocol else {
            return nil
        }

        let localizationManager = LocalizationManager.shared

        let profileViewModelFactory = SettingsViewModelFactory(
            iconGenerator: NovaIconGenerator(),
            quantityFormatter: NumberFormatter.quantity.localizableResource()
        )

        let interactor = SettingsInteractor(
            selectedWalletSettings: SelectedWalletSettings.shared,
            eventCenter: EventCenter.shared,
            walletConnect: walletConnect,
            currencyManager: currencyManager
        )

        let wireframe = SettingsWireframe(dappMediator: dappMediator)

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
