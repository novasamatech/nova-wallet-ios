import Foundation
import Foundation_iOS

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
    func close(view: ControllerBackedProtocol?)

    func showAdvancedSettings(
        from view: ControllerBackedProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    )
}

extension ExportGenericWireframeProtocol {
    func close(view: ControllerBackedProtocol?) {
        view?.controller.navigationController?.popToRootViewController(animated: true)
    }

    func showAdvancedSettings(
        from view: ControllerBackedProtocol?,
        secretSource: SecretSource,
        settings: AdvancedWalletSettings
    ) {
        guard let advancedView = AdvancedWalletViewFactory.createReadonlyView(
            for: secretSource,
            advancedSettings: settings
        ) else {
            return
        }

        let navigationController = NovaNavigationController(rootViewController: advancedView.controller)

        view?.controller.presentWithCardLayout(
            navigationController,
            animated: true,
            completion: nil
        )
    }
}
