import Foundation
import SoraFoundation

final class OnboardingMainPresenter {
    weak var view: OnboardingMainViewProtocol?
    let wireframe: OnboardingMainWireframeProtocol
    let interactor: OnboardingMainInteractorInputProtocol

    let legalData: LegalData

    let locale: Locale

    init(
        interactor: OnboardingMainInteractorInputProtocol,
        wireframe: OnboardingMainWireframeProtocol,
        legalData: LegalData,
        locale: Locale
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.legalData = legalData
        self.locale = locale
    }
}

extension OnboardingMainPresenter: OnboardingMainPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func activateTerms() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.termsUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activatePrivacy() {
        if let view = view {
            wireframe.showWeb(
                url: legalData.privacyPolicyUrl,
                from: view,
                style: .modal
            )
        }
    }

    func activateSignup() {
        wireframe.showSignup(from: view)
    }

    func activateAccountRestore() {
        wireframe.showAccountRestore(from: view)
    }

    func activateWatchOnlyCreate() {
        wireframe.showWatchOnlyCreate(from: view)
    }

    func activateHardwareWalletCreate() {
        guard let view = view else {
            return
        }

        let hwWalletOptions: [HardwareWalletOptions] = [.polkadotVault, .ledger, .paritySigner]

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
                        icon: R.image.iconLedgerAction(),
                        title: R.string.localizable.commonLedgerNanoX(preferredLanguages: locale.rLanguages),
                        details: nil
                    )
                }
            }
        }

        let title = LocalizableResource { locale in
            R.string.localizable.hardwareWalletOptionsTitle(preferredLanguages: locale.rLanguages)
        }

        wireframe.presentActionsManage(
            from: view,
            actions: viewModels,
            title: title,
            delegate: self,
            context: nil
        )
    }
}

extension OnboardingMainPresenter: OnboardingMainInteractorOutputProtocol {
    func didSuggestSecretImport(source: SecretSource) {
        wireframe.showAccountSecretImport(from: view, source: source)
    }

    func didReceiveError(_ error: Error) {
        _ = wireframe.present(error: error, from: view, locale: locale)
    }
}

extension OnboardingMainPresenter: ModalPickerViewControllerDelegate {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context _: AnyObject?) {
        guard let option = HardwareWalletOptions(rawValue: UInt8(index)) else {
            return
        }

        switch option {
        case .paritySigner:
            wireframe.showParitySignerWalletCreation(from: view, type: .legacy)
        case .polkadotVault:
            wireframe.showParitySignerWalletCreation(from: view, type: .vault)
        case .ledger:
            wireframe.showLedgerWalletCreation(from: view)
        }
    }
}
