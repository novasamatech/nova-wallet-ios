import Foundation
import Foundation_iOS

class WalletImportOptionsWireframe: ActionsManagePresentable {
    class HDWalletsContext {
        let view: ControllerBackedProtocol?
        let options: [HardwareWalletOptions]

        init(view: ControllerBackedProtocol?, options: [HardwareWalletOptions]) {
            self.view = view
            self.options = options
        }
    }

    let chainRegistry: ChainRegistryProtocol

    init(chainRegistry: ChainRegistryProtocol) {
        self.chainRegistry = chainRegistry
    }

    func showSeedImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .seed)
    }

    func showRestoreJsonImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .keystore)
    }

    func showPassphraseImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .mnemonic(.appDefault))
    }

    func showHardwareImport(from view: WalletImportOptionsViewProtocol?, locale: Locale) {
        showHardwareWalletSelection(from: view, locale: locale)
    }

    func showTrustWalletImport(from view: WalletImportOptionsViewProtocol?) {
        showWalletRestore(from: view, secretSource: .mnemonic(.trustWallet))
    }

    func showHardwareWalletSelection(from view: WalletImportOptionsViewProtocol?, locale: Locale) {
        guard let view = view else {
            return
        }

        let isLedgerGenericAvailable = chainRegistry.genericLedgerAvailable()

        let hwWalletOptions: [HardwareWalletOptions] = if isLedgerGenericAvailable {
            [.polkadotVault, .genericLedger, .ledger, .paritySigner]
        } else {
            [.polkadotVault, .ledger, .paritySigner]
        }

        let viewModels: [LocalizableResource<ActionManageViewModel>] = hwWalletOptions.map { option in
            switch option {
            case .paritySigner:
                LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: ParitySignerType.legacy.iconForAction,
                        title: ParitySignerType.legacy.getName(for: locale),
                        details: nil
                    )
                }
            case .polkadotVault:
                LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: ParitySignerType.vault.iconForAction,
                        title: ParitySignerType.vault.getName(for: locale),
                        details: nil
                    )
                }
            case .ledger:
                if isLedgerGenericAvailable {
                    LocalizableResource { locale in
                        ActionManageViewModel(
                            icon: R.image.iconLedgerActionWarning(),
                            title: R.string.localizable.commonLedgerLegacy(preferredLanguages: locale.rLanguages),
                            details: nil,
                            allowsIconModification: false
                        )
                    }
                } else {
                    LocalizableResource { locale in
                        ActionManageViewModel(
                            icon: R.image.iconLedgerAction(),
                            title: R.string.localizable.commonLedgerNanoX(preferredLanguages: locale.rLanguages),
                            details: nil
                        )
                    }
                }
            case .genericLedger:
                LocalizableResource { locale in
                    ActionManageViewModel(
                        icon: R.image.iconLedgerAction(),
                        title: R.string.localizable.commonLedgerNanoGeneric(preferredLanguages: locale.rLanguages),
                        subtitle: [
                            R.string.localizable.commonLedgerModelFlex(preferredLanguages: locale.rLanguages),
                            R.string.localizable.commonLedgerModelStax(preferredLanguages: locale.rLanguages),
                            R.string.localizable.commonLedgerModelNanoX(preferredLanguages: locale.rLanguages)
                        ].joined(with: .commaSpace),
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
            context: HDWalletsContext(
                view: view,
                options: hwWalletOptions
            )
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
        guard let hdContext = context as? HDWalletsContext else {
            return
        }

        let option = hdContext.options[index]
        let view = hdContext.view

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
