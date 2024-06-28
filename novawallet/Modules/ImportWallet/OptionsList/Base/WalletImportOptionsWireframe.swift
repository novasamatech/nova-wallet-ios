import Foundation
import SoraFoundation

class WalletImportOptionsWireframe: ActionsManagePresentable {
    func showSeedImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .seed)
    }

    func showRestoreJsonImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .keystore)
    }

    func showPassphraseImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .mnemonic)
    }

    func showHardwareImport(from view: WalletImportOptionsViewProtocol?, locale: Locale) {
        showHardwareWalletSelection(from: view, locale: locale)
    }

    func showHardwareWalletSelection(from view: WalletImportOptionsViewProtocol?, locale: Locale) {
        guard let view = view else {
            return
        }

        let hwWalletOptions: [HardwareWalletOptions] = [.polkadotVault, .genericLedger, .ledger, .paritySigner]

        let viewModels: [LocalizableResource<ActionManageViewModel>] = hwWalletOptions.map { option in
            switch option {
            case .paritySigner:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: ParitySignerType.legacy.iconForAction,
                        title: ParitySignerType.legacy.getName(for: locale),
                        details: nil
                    )
                }
            case .polkadotVault:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: ParitySignerType.vault.iconForAction,
                        title: ParitySignerType.vault.getName(for: locale),
                        details: nil
                    )
                }
            case .ledger:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconLedgerActionWarning(),
                        title: R.string.localizable.commonLedgerNanoLegacy(preferredLanguages: locale.rLanguages),
                        details: nil
                    )
                }
            case .genericLedger:
                return LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconLedgerAction(),
                        title: R.string.localizable.commonLedgerNanoGeneric(preferredLanguages: locale.rLanguages),
                        details: nil
                    )
                }
            }
        }

        let title = LocalizableResource { locale in
            R.string.localizable.hardwareWalletOptionsTitle(preferredLanguages: locale.rLanguages)
        }

        presentActionsManage(
            from: view,
            actions: viewModels,
            title: title,
            delegate: self,
            context: view
        )
    }

    func showParitySignerWalletCreation(from _: ControllerBackedProtocol?, type _: ParitySignerType) {
        fatalError("Must be overriden in subclass")
    }

    func showLedgerWalletCreation(from _: ControllerBackedProtocol?, appType _: LedgerWalletType) {
        fatalError("Must be overriden in subclass")
    }

    func showWalletRestore(from _: WalletImportOptionsViewProtocol?, secretSource _: SecretSource) {
        fatalError("Must be overriden in subclass")
    }
}

extension WalletImportOptionsWireframe: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {
        guard
            let option = HardwareWalletOptions(rawValue: UInt8(index)),
            let view = context as? ControllerBackedProtocol else {
            return
        }

        switch option {
        case .paritySigner:
            showParitySignerWalletCreation(from: view, type: .legacy)
        case .polkadotVault:
            showParitySignerWalletCreation(from: view, type: .vault)
        case .ledger:
            showLedgerWalletCreation(from: view, appType: .legacy)
        case .genericLedger:
            showLedgerWalletCreation(from: view, appType: .generic)
        }
    }
}
