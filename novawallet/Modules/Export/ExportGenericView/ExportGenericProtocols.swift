import Foundation
import SoraFoundation

protocol ExportGenericViewProtocol: ControllerBackedProtocol {
    func set(viewModel: ExportGenericViewModel)
}

protocol ExportGenericPresenterProtocol {
    func setup()
    func activateExport()
    func activateAdvancedSettings()
}

extension ExportGenericPresenterProtocol {
    func activateAccessoryOption() {}
}

protocol ExportGenericWireframeProtocol: ErrorPresentable, AlertPresentable, SharingPresentable {
    func close(view: ExportGenericViewProtocol?)

    func showAdvancedSettings(
        from view: ExportGenericViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    )
}

extension ExportGenericWireframeProtocol {
    func close(view: ExportGenericViewProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }

    func showAdvancedSettings(
        from view: ExportGenericViewProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    ) {
        guard let advancedView = AdvancedWalletViewFactory.createReadonlyView(
            for: secretSource,
            advancedSettings: settings
        ) else {
            return
        }

        let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
