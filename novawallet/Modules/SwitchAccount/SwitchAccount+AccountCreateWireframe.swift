import Foundation

extension SwitchAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func showAdvancedSettings(from view: AccountCreateViewProtocol?, secretSource: SecretSource, settings: AdvancedWalletSettings, delegate: AdvancedWalletSettingsDelegate) {
            guard let advancedView = AdvancedWalletViewFactory.createView(
                for: secretSource,
                advancedSettings: settings,
                delegate: delegate
            ) else {
                return
            }

            let navigationController = FearlessNavigationController(rootViewController: advancedView.controller)

            view?.controller.present(navigationController, animated: true)
        }

        func confirm(
            from view: OldAccountCreateViewProtocol?,
            request: MetaAccountCreationRequest,
            metadata: MetaAccountCreationMetadata
        ) {
            guard let accountConfirmation = AccountConfirmViewFactory
                .createViewForSwitch(request: request, metadata: metadata)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(accountConfirmation, animated: true)
            }
        }

        func presentCryptoTypeSelection(
            from view: OldAccountCreateViewProtocol?,
            availableTypes: [MultiassetCryptoType],
            selectedType: MultiassetCryptoType,
            delegate: ModalPickerViewControllerDelegate?,
            context: AnyObject?
        ) {
            guard let modalPicker = ModalPickerFactory.createPickerForList(
                availableTypes,
                selectedType: selectedType,
                delegate: delegate,
                context: context
            ) else {
                return
            }

            view?.controller.navigationController?.present(
                modalPicker,
                animated: true,
                completion: nil
            )
        }
    }
}
